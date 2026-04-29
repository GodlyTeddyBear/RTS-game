--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BehaviorSystem = require(ReplicatedStorage.Utilities.BehaviorSystem)

local HookRunner = require(script.Parent.HookRunner)
local Types = require(script.Parent.Types)
local Validation = require(script.Parent.Validation)

type TConfig = Types.TConfig
type TActionDefinition = Types.TActionDefinition
type TActionState = Types.TActionState
type TActorAdapter = Types.TActorAdapter
type TFrameContext = Types.TFrameContext
type TRunFrameEntityResult = Types.TRunFrameEntityResult
type TRunFrameResult = Types.TRunFrameResult
type TErrorSinkPayload = Types.TErrorSinkPayload

type THookOutcome = HookRunner.THookOutcome

type TEntityFrameState = {
	Entity: number,
	ActorType: string,
	Adapter: TActorAdapter,
	Result: TRunFrameEntityResult,
	HookOutcome: THookOutcome,
	BehaviorTree: any?,
}

local _ResolveActorTypes
local _BuildTreeContext
local _CloneActionState
local _GetActorLabel

local Runtime = {}
Runtime.__index = Runtime

function Runtime.new(config: TConfig)
	Validation.ValidateConfig(config)

	local self = setmetatable({}, Runtime)
	self._runtime = BehaviorSystem.new({
		Conditions = config.Conditions,
		Commands = config.Commands,
	})
	self._hooks = config.Hooks
	self._errorSink = config.ErrorSink
	self._actorAdapters = {}
	self._actorOrder = {}

	return self
end

function Runtime:RegisterActions(definitions: { [any]: TActionDefinition })
	self._runtime:RegisterActions(definitions)
end

function Runtime:RegisterActorType(actorType: string, adapter: TActorAdapter)
	Validation.ValidateActorType(actorType)
	Validation.ValidateActorAdapter(actorType, adapter)
	assert(self._actorAdapters[actorType] == nil, ("AiRuntime actor type '%s' is already registered"):format(actorType))

	self._actorAdapters[actorType] = adapter
	table.insert(self._actorOrder, actorType)
end

function Runtime:BuildTree(definition: any)
	return self._runtime:BuildTree(definition)
end

function Runtime:GetExecutor(actionId: string)
	return self._runtime:GetExecutor(actionId)
end

function Runtime:RunFrame(frameContext: TFrameContext): TRunFrameResult
	Validation.ValidateFrameContext(frameContext)

	local defects = {}
	local entityResults = {}
	local actorTypes = _ResolveActorTypes(frameContext, self._actorAdapters, self._actorOrder)

	for _, actorType in ipairs(actorTypes) do
		local adapter = self._actorAdapters[actorType]
		local entityStates = self:_BuildEntityStates(actorType, adapter, frameContext, defects, entityResults)

		self:_RunTreePhase(entityStates, frameContext, defects)
		self:_RunTransitionPhase(entityStates, frameContext, defects)
		self:_RunActionPhase(entityStates, frameContext, defects)
	end

	return table.freeze({
		EntityResults = entityResults,
		Defects = defects,
	})
end

function Runtime:_BuildEntityStates(
	actorType: string,
	adapter: TActorAdapter,
	frameContext: TFrameContext,
	defects: { TErrorSinkPayload },
	entityResults: { TRunFrameEntityResult }
): { TEntityFrameState }
	local entityStates = {}
	local entities = adapter:QueryActiveEntities(frameContext)
	assert(type(entities) == "table", ("AiRuntime adapter '%s' QueryActiveEntities must return an array"):format(actorType))

	for _, entity in ipairs(entities) do
		local result = {
			ActorType = actorType,
			Entity = entity,
			TreeStatus = "SkippedNoTree",
			StartStatus = nil,
			CommitStatus = nil,
			TickStatus = nil,
			ResolveStatus = nil,
		}
		table.insert(entityResults, result)

		local actionState = _CloneActionState(adapter:GetActionState(entity))
		local baseServices = if frameContext.Services ~= nil then frameContext.Services else {}
		local hookContext = {
			Entity = entity,
			ActorType = actorType,
			ActionState = actionState,
			FrameContext = frameContext,
			Services = baseServices,
			Adapter = adapter,
		}

		local hookOutcome = self:_RunHooks(entity, actorType, adapter, hookContext, defects)
		local behaviorTree = adapter:GetBehaviorTree(entity)

		table.insert(entityStates, {
			Entity = entity,
			ActorType = actorType,
			Adapter = adapter,
			Result = result,
			HookOutcome = hookOutcome,
			BehaviorTree = behaviorTree,
		})
	end

	return entityStates
end

function Runtime:_RunTreePhase(
	entityStates: { TEntityFrameState },
	frameContext: TFrameContext,
	defects: { TErrorSinkPayload }
)
	for _, entityState in ipairs(entityStates) do
		if entityState.BehaviorTree == nil then
			entityState.Result.TreeStatus = "SkippedNoTree"
			continue
		end

		if not entityState.Adapter:ShouldEvaluate(entityState.Entity, frameContext.CurrentTime) then
			entityState.Result.TreeStatus = "SkippedNotReady"
			continue
		end

		local treeContext = _BuildTreeContext(entityState.Entity, entityState.ActorType, entityState.Adapter, entityState.HookOutcome)
		local didRun, runError = pcall(function()
			entityState.BehaviorTree.TreeInstance:run(treeContext)
		end)

		if not didRun then
			entityState.Result.TreeStatus = "TreeDefect"
			self:_PushDefect(defects, {
				Stage = "TreeRun",
				ActorType = entityState.ActorType,
				Entity = entityState.Entity,
				ActorLabel = _GetActorLabel(entityState.Adapter),
				ErrorType = "TreeRunFailed",
				ErrorMessage = tostring(runError),
				Details = nil,
			})
			continue
		end

		entityState.Result.TreeStatus = "Ran"
		entityState.Adapter:UpdateLastTickTime(entityState.Entity, frameContext.CurrentTime)
	end
end

function Runtime:_RunTransitionPhase(
	entityStates: { TEntityFrameState },
	frameContext: TFrameContext,
	defects: { TErrorSinkPayload }
)
	for _, entityState in ipairs(entityStates) do
		local actionState = _CloneActionState(entityState.Adapter:GetActionState(entityState.Entity))
		local runtimeContext = {
			DeltaTime = frameContext.DeltaTime,
			Services = entityState.HookOutcome.Services,
		}
		local startResult = self._runtime:StartPendingAction(entityState.Entity, actionState, runtimeContext)

		if not startResult.success then
			self:_PushRuntimeFailure(
				defects,
				"StartPendingAction",
				entityState,
				startResult.type,
				startResult.message,
				nil
			)
			entityState.Adapter:ClearActionState(entityState.Entity)
			continue
		end

		local startStatus = startResult.value.Status
		entityState.Result.StartStatus = startStatus

		if startStatus == "NoAction" or startStatus == "Blocked" then
			continue
		end

		if startStatus == "NoChange" then
			actionState.PendingActionId = nil
			actionState.PendingActionData = nil
			entityState.Adapter:SetActionState(entityState.Entity, actionState)
			continue
		end

		if startStatus == "MissingAction" or startStatus == "FailedToStart" then
			entityState.Adapter:ClearActionState(entityState.Entity)
			continue
		end

		local commitResult = self._runtime:CommitStartedAction(actionState, startResult.value, frameContext.CurrentTime)
		entityState.Result.CommitStatus = commitResult.Status

		if commitResult.Status == "Committed" then
			entityState.Adapter:SetActionState(entityState.Entity, actionState)
			continue
		end

		self:_PushDefect(defects, {
			Stage = "CommitStartedAction",
			ActorType = entityState.ActorType,
			Entity = entityState.Entity,
			ActorLabel = _GetActorLabel(entityState.Adapter),
			ErrorType = "InvalidCommitTransition",
			ErrorMessage = "AiRuntime received an invalid commit transition",
			Details = {
				StartStatus = startStatus,
				CommitStatus = commitResult.Status,
			},
		})
		entityState.Adapter:ClearActionState(entityState.Entity)
	end
end

function Runtime:_RunActionPhase(
	entityStates: { TEntityFrameState },
	frameContext: TFrameContext,
	defects: { TErrorSinkPayload }
)
	for _, entityState in ipairs(entityStates) do
		local actionState = _CloneActionState(entityState.Adapter:GetActionState(entityState.Entity))
		local runtimeContext = {
			DeltaTime = frameContext.DeltaTime,
			Services = entityState.HookOutcome.Services,
		}
		local tickResult = self._runtime:TickCurrentAction(entityState.Entity, actionState, runtimeContext)

		if not tickResult.success then
			self:_PushRuntimeFailure(
				defects,
				"TickCurrentAction",
				entityState,
				tickResult.type,
				tickResult.message,
				nil
			)
			entityState.Adapter:ClearActionState(entityState.Entity)
			continue
		end

		local tickStatus = tickResult.value.Status
		entityState.Result.TickStatus = tickStatus

		local resolveResult = self._runtime:ResolveFinishedAction(actionState, tickResult.value, frameContext.CurrentTime)
		entityState.Result.ResolveStatus = resolveResult.Status

		if resolveResult.Status == "Resolved" then
			entityState.Adapter:SetActionState(entityState.Entity, actionState)
			continue
		end

		if resolveResult.Status == "InvalidResult" then
			self:_PushDefect(defects, {
				Stage = "ResolveFinishedAction",
				ActorType = entityState.ActorType,
				Entity = entityState.Entity,
				ActorLabel = _GetActorLabel(entityState.Adapter),
				ErrorType = "InvalidResolveTransition",
				ErrorMessage = "AiRuntime received an invalid resolve transition",
				Details = {
					TickStatus = tickStatus,
					ActionId = tickResult.value.ActionId,
				},
			})
			entityState.Adapter:ClearActionState(entityState.Entity)
		end
	end
end

function Runtime:_RunHooks(
	entity: number,
	actorType: string,
	adapter: TActorAdapter,
	hookContext: Types.THookContext,
	defects: { TErrorSinkPayload }
): THookOutcome
	local didRun, hookOutcome = pcall(function()
		return HookRunner.Run(self._hooks, entity, hookContext)
	end)

	if didRun then
		return hookOutcome
	end

	self:_PushDefect(defects, {
		Stage = "HookRun",
		ActorType = actorType,
		Entity = entity,
		ActorLabel = _GetActorLabel(adapter),
		ErrorType = "HookRunFailed",
		ErrorMessage = tostring(hookOutcome),
		Details = nil,
	})

	return {
		Facts = {},
		BehaviorContext = {},
		Services = hookContext.Services,
	}
end

function Runtime:_PushRuntimeFailure(
	defects: { TErrorSinkPayload },
	stage: string,
	entityState: TEntityFrameState,
	errorType: string,
	errorMessage: string,
	details: { [string]: any }?
)
	self:_PushDefect(defects, {
		Stage = stage,
		ActorType = entityState.ActorType,
		Entity = entityState.Entity,
		ActorLabel = _GetActorLabel(entityState.Adapter),
		ErrorType = errorType,
		ErrorMessage = errorMessage,
		Details = details,
	})
end

function Runtime:_PushDefect(defects: { TErrorSinkPayload }, payload: TErrorSinkPayload)
	table.insert(defects, payload)

	if self._errorSink ~= nil then
		self._errorSink(payload)
	end
end

function _ResolveActorTypes(
	frameContext: TFrameContext,
	actorAdapters: { [string]: TActorAdapter },
	actorOrder: { string }
): { string }
	if frameContext.ActorTypes == nil then
		return actorOrder
	end

	for _, actorType in ipairs(frameContext.ActorTypes) do
		assert(actorAdapters[actorType] ~= nil, ("AiRuntime frame requested unknown actor type '%s'"):format(actorType))
	end

	return frameContext.ActorTypes
end

function _BuildTreeContext(
	entity: number,
	actorType: string,
	adapter: TActorAdapter,
	hookOutcome: THookOutcome
): { [string]: any }
	local treeContext = {
		Entity = entity,
		ActorType = actorType,
		Facts = hookOutcome.Facts,
		ActionFactory = adapter,
	}

	for key, value in pairs(hookOutcome.BehaviorContext) do
		if key ~= "Entity" and key ~= "ActorType" and key ~= "Facts" and key ~= "ActionFactory" then
			treeContext[key] = value
		end
	end

	return treeContext
end

function _CloneActionState(actionState: TActionState?): TActionState
	if actionState == nil then
		return {
			CurrentActionId = nil,
			ActionState = "Idle",
			ActionData = nil,
			PendingActionId = nil,
			PendingActionData = nil,
			StartedAt = nil,
			FinishedAt = nil,
		}
	end

	return {
		CurrentActionId = actionState.CurrentActionId,
		ActionState = actionState.ActionState or "Idle",
		ActionData = actionState.ActionData,
		PendingActionId = actionState.PendingActionId,
		PendingActionData = actionState.PendingActionData,
		StartedAt = (actionState :: any).StartedAt or (actionState :: any).ActionStartedAt,
		FinishedAt = (actionState :: any).FinishedAt,
	}
end

function _GetActorLabel(adapter: TActorAdapter): string?
	if adapter.GetActorLabel == nil then
		return nil
	end

	return adapter:GetActorLabel()
end

return table.freeze(Runtime)
