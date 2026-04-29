--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BehaviorSystem = require(ReplicatedStorage.Utilities.AI.Behavior)

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
type TCleanupKind = Types.TCleanupKind
type TCleanupResult = Types.TCleanupResult
type TCleanupBatchResult = Types.TCleanupBatchResult

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
local _BuildCleanupResult

--[=[
	@class AiRuntimeService
	Runs the shared AI frame loop while keeping actor state and cleanup ownership in the caller's context.
	@server
	@client
]=]

local Runtime = {}
Runtime.__index = Runtime

--[=[
	Creates one AI runtime service from condition, command, hook, and error-sink registries.
	@within AiRuntimeService
	@param config TConfig
	@return any
]=]
function Runtime.new(config: TConfig)
	Validation.ValidateConfig(config)

	-- The shared BehaviorSystem handles tree compilation while this runtime keeps orchestration and adapter state.
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

--[=[
	Registers action definitions on the shared BehaviorSystem runtime.
	@within AiRuntimeService
	@param definitions { [any]: TActionDefinition }
]=]
function Runtime:RegisterActions(definitions: { [any]: TActionDefinition })
	self._runtime:RegisterActions(definitions)
end

--[=[
	Registers one actor adapter under one actor type.
	@within AiRuntimeService
	@param actorType string
	@param adapter TActorAdapter
]=]
function Runtime:RegisterActorType(actorType: string, adapter: TActorAdapter)
	Validation.ValidateActorType(actorType)
	Validation.ValidateActorAdapter(actorType, adapter)
	assert(self._actorAdapters[actorType] == nil, ("AiRuntime actor type '%s' is already registered"):format(actorType))

	self._actorAdapters[actorType] = adapter
	table.insert(self._actorOrder, actorType)
end

--[=[
	Compiles one behavior-tree definition through the shared BehaviorSystem runtime.
	@within AiRuntimeService
	@param definition any
	@return any
]=]
function Runtime:BuildTree(definition: any)
	return self._runtime:BuildTree(definition)
end

--[=[
	Returns one registered executor by action id.
	@within AiRuntimeService
	@param actionId string
	@return any
]=]
function Runtime:GetExecutor(actionId: string)
	return self._runtime:GetExecutor(actionId)
end

--[=[
	Cancels one actor's current action through the cleanup boundary.
	@within AiRuntimeService
	@param actorType string
	@param entity number
	@param frameContext TFrameContext
	@return TCleanupResult
]=]
function Runtime:CancelActorAction(actorType: string, entity: number, frameContext: TFrameContext): TCleanupResult
	return self:_CleanupActorAction("Cancel", actorType, entity, frameContext)
end

--[=[
	Handles one actor death through the cleanup boundary.
	@within AiRuntimeService
	@param actorType string
	@param entity number
	@param frameContext TFrameContext
	@return TCleanupResult
]=]
function Runtime:HandleActorDeath(actorType: string, entity: number, frameContext: TFrameContext): TCleanupResult
	return self:_CleanupActorAction("Death", actorType, entity, frameContext)
end

--[=[
	Cancels many actor actions in order.
	@within AiRuntimeService
	@param actorType string
	@param entities { number }
	@param frameContext TFrameContext
	@return TCleanupBatchResult
]=]
function Runtime:CancelActorActions(actorType: string, entities: { number }, frameContext: TFrameContext): TCleanupBatchResult
	Validation.ValidateActorType(actorType)
	assert(type(entities) == "table", "AiRuntime CancelActorActions entities must be an array")
	Validation.ValidateFrameContext(frameContext)

	local cleanupResults = {}
	for _, entity in ipairs(entities) do
		table.insert(cleanupResults, self:CancelActorAction(actorType, entity, frameContext))
	end

	return table.freeze(cleanupResults)
end

--[=[
	Handles many actor deaths in order.
	@within AiRuntimeService
	@param actorType string
	@param entities { number }
	@param frameContext TFrameContext
	@return TCleanupBatchResult
]=]
function Runtime:HandleActorDeaths(actorType: string, entities: { number }, frameContext: TFrameContext): TCleanupBatchResult
	Validation.ValidateActorType(actorType)
	assert(type(entities) == "table", "AiRuntime HandleActorDeaths entities must be an array")
	Validation.ValidateFrameContext(frameContext)

	local cleanupResults = {}
	for _, entity in ipairs(entities) do
		table.insert(cleanupResults, self:HandleActorDeath(actorType, entity, frameContext))
	end

	return table.freeze(cleanupResults)
end

--[=[
	Runs one AI frame across all registered actor types.
	@within AiRuntimeService
	@param frameContext TFrameContext
	@return TRunFrameResult
]=]
function Runtime:RunFrame(frameContext: TFrameContext): TRunFrameResult
	Validation.ValidateFrameContext(frameContext)

	-- Frame execution is deliberately staged so defects can be attributed to the exact phase that failed.
	local defects = {}
	local entityResults = {}
	local actorTypes = _ResolveActorTypes(frameContext, self._actorAdapters, self._actorOrder)

	for _, actorType in ipairs(actorTypes) do
		local adapter = self._actorAdapters[actorType]
		-- Build a single snapshot list so the later phases work from the same entity set.
		local entityStates = self:_BuildEntityStates(actorType, adapter, frameContext, defects, entityResults)

		-- Tree evaluation decides whether the entity should issue a new pending action.
		self:_RunTreePhase(entityStates, frameContext, defects)
		-- Transition handling promotes pending actions into the active action slot.
		self:_RunTransitionPhase(entityStates, frameContext, defects)
		-- Tick handling advances the active action and resolves terminal results.
		self:_RunActionPhase(entityStates, frameContext, defects)
	end

	return table.freeze({
		EntityResults = entityResults,
		Defects = defects,
	})
end

--[=[
	@private
	Builds the per-entity snapshots used by the tree, transition, and action phases.
	@within AiRuntimeService
	@param actorType string
	@param adapter TActorAdapter
	@param frameContext TFrameContext
	@param defects { TErrorSinkPayload }
	@param entityResults { TRunFrameEntityResult }
	@return { any }
]=]
function Runtime:_BuildEntityStates(
	actorType: string,
	adapter: TActorAdapter,
	frameContext: TFrameContext,
	defects: { TErrorSinkPayload },
	entityResults: { TRunFrameEntityResult }
): { TEntityFrameState }
	-- Entity state snapshots let the three runtime phases share the same per-entity inputs without repeated adapter calls.
	local entityStates = {}
	local entities = adapter:QueryActiveEntities(frameContext)
	assert(type(entities) == "table", ("AiRuntime adapter '%s' QueryActiveEntities must return an array"):format(actorType))

	for _, entity in ipairs(entities) do
		-- Seed a result record before the per-phase work fills in status fields.
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

		-- Pull hook output before tree execution so facts and services are ready for the behavior tree.
		local hookOutcome = self:_BuildHookOutcome(actorType, entity, adapter, frameContext, defects)
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

--[=[
	@private
	Runs the cleanup boundary for one actor and clears action state after the shared runtime call.
	@within AiRuntimeService
	@param cleanupKind TCleanupKind
	@param actorType string
	@param entity number
	@param frameContext TFrameContext
	@return TCleanupResult
]=]
function Runtime:_CleanupActorAction(
	cleanupKind: TCleanupKind,
	actorType: string,
	entity: number,
	frameContext: TFrameContext
): TCleanupResult
	Validation.ValidateActorType(actorType)
	Validation.ValidateFrameContext(frameContext)

	local adapter = self:_RequireActorAdapter(actorType)
	if adapter == nil then
		-- Return a structured invalid-type result instead of throwing so cleanup can stay caller-safe.
		return _BuildCleanupResult(actorType, entity, cleanupKind, "InvalidActorType", nil)
	end

	local defects = {}
	local actionState = _CloneActionState(adapter:GetActionState(entity))
	-- Reuse the normal hook merge path so cleanup sees the same service bag as frame execution.
	local hookOutcome = self:_BuildHookOutcome(actorType, entity, adapter, frameContext, defects)
	local runtimeContext = {
		DeltaTime = frameContext.DeltaTime,
		Services = hookOutcome.Services,
	}

	-- Cleanup uses the same runtime boundary as frame execution so cancellation and death stay behavior-system aware.
	local cleanupResult = if cleanupKind == "Cancel"
		then self._runtime:CancelCurrentAction(entity, actionState, runtimeContext)
		else self._runtime:HandleCurrentActionDeath(entity, actionState, runtimeContext)

	if not cleanupResult.success then
		-- Cleanup failures still clear the adapter state so stale actions do not linger after the defect.
		local defect = {
			Stage = if cleanupKind == "Cancel" then "CancelActorAction" else "HandleActorDeath",
			ActorType = actorType,
			Entity = entity,
			ActorLabel = _GetActorLabel(adapter),
			ErrorType = cleanupResult.type,
			ErrorMessage = cleanupResult.message,
			Details = nil,
		}
		self:_PushDefect(defects, defect)
		adapter:ClearActionState(entity)

		return _BuildCleanupResult(actorType, entity, cleanupKind, "ClearedAfterFailure", defect)
	end

	adapter:ClearActionState(entity)

	if cleanupResult.value.Status == "NoCurrentAction" then
		-- A no-op cleanup still returns a distinct status for callers that care about the empty-path case.
		return _BuildCleanupResult(actorType, entity, cleanupKind, "NoCurrentAction", nil)
	end

	return _BuildCleanupResult(actorType, entity, cleanupKind, "Handled", nil)
end

--[=[
	@private
	Returns the registered adapter for one actor type, if present.
	@within AiRuntimeService
	@param actorType string
	@return TActorAdapter?
]=]
function Runtime:_RequireActorAdapter(actorType: string): TActorAdapter?
	return self._actorAdapters[actorType]
end

--[=[
	@private
	Builds the hook context and runs the ordered hook chain for one entity.
	@within AiRuntimeService
	@param actorType string
	@param entity number
	@param adapter TActorAdapter
	@param frameContext TFrameContext
	@param defects { TErrorSinkPayload }
	@return THookOutcome
]=]
function Runtime:_BuildHookOutcome(
	actorType: string,
	entity: number,
	adapter: TActorAdapter,
	frameContext: TFrameContext,
	defects: { TErrorSinkPayload }
): THookOutcome
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

	return self:_RunHooks(entity, actorType, adapter, hookContext, defects)
end

--[=[
	@private
	Runs the tree-evaluation phase for one batch of entity snapshots.
	@within AiRuntimeService
	@param entityStates { TEntityFrameState }
	@param frameContext TFrameContext
	@param defects { TErrorSinkPayload }
]=]
function Runtime:_RunTreePhase(
	entityStates: { TEntityFrameState },
	frameContext: TFrameContext,
	defects: { TErrorSinkPayload }
)
	for _, entityState in ipairs(entityStates) do
		if entityState.BehaviorTree == nil then
			-- No tree means there is nothing to evaluate for this entity.
			entityState.Result.TreeStatus = "SkippedNoTree"
			continue
		end

		if not entityState.Adapter:ShouldEvaluate(entityState.Entity, frameContext.CurrentTime) then
			-- The adapter owns the tick gate, so the runtime skips entities that are not ready yet.
			entityState.Result.TreeStatus = "SkippedNotReady"
			continue
		end

		local treeContext = _BuildTreeContext(entityState.Entity, entityState.ActorType, entityState.Adapter, entityState.HookOutcome)
		local didRun, runError = pcall(function()
			entityState.BehaviorTree.TreeInstance:run(treeContext)
		end)

		if not didRun then
			-- Tree execution defects stay isolated to the tree phase and do not stop later entities.
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
		-- The tree advanced successfully, so the adapter records the new tick time for the next frame.
		entityState.Adapter:UpdateLastTickTime(entityState.Entity, frameContext.CurrentTime)
	end
end

--[=[
	@private
	Runs the pending-action transition phase for one batch of entity snapshots.
	@within AiRuntimeService
	@param entityStates { TEntityFrameState }
	@param frameContext TFrameContext
	@param defects { TErrorSinkPayload }
]=]
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
			-- Failed starts clear the action state so the next frame can retry from a clean boundary.
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
			-- These statuses intentionally leave the action state unchanged.
			continue
		end

		if startStatus == "NoChange" then
			-- No-change means the pending action should be dropped but the current action should stay intact.
			actionState.PendingActionId = nil
			actionState.PendingActionData = nil
			entityState.Adapter:SetActionState(entityState.Entity, actionState)
			continue
		end

		if startStatus == "MissingAction" or startStatus == "FailedToStart" then
			-- Missing or failed starts reset the adapter state so the entity does not retain a bad pending action.
			entityState.Adapter:ClearActionState(entityState.Entity)
			continue
		end

		local commitResult = self._runtime:CommitStartedAction(actionState, startResult.value, frameContext.CurrentTime)
		entityState.Result.CommitStatus = commitResult.Status

		if commitResult.Status == "Committed" then
			-- A successful commit writes the updated action state back to the adapter.
			entityState.Adapter:SetActionState(entityState.Entity, actionState)
			continue
		end

		-- Invalid transitions are reported as defects because the runtime should only see valid commit outcomes.
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

--[=[
	@private
	Runs the current-action tick and resolve phase for one batch of entity snapshots.
	@within AiRuntimeService
	@param entityStates { TEntityFrameState }
	@param frameContext TFrameContext
	@param defects { TErrorSinkPayload }
]=]
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
			-- Tick failures clear the action state so the runtime can recover on the next frame.
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
			-- Resolved actions keep the updated state because the action may have advanced into a new terminal status.
			entityState.Adapter:SetActionState(entityState.Entity, actionState)
			continue
		end

		if resolveResult.Status == "InvalidResult" then
			-- Invalid resolve transitions are defects because the shared runtime rejected the terminal status.
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

--[=[
	@private
	Runs the hook chain for one entity and converts failures into a neutral outcome.
	@within AiRuntimeService
	@param entity number
	@param actorType string
	@param adapter TActorAdapter
	@param hookContext Types.THookContext
	@param defects { TErrorSinkPayload }
	@return THookOutcome
]=]
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

	-- Hook failures collapse to a neutral payload so frame execution can keep moving.
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
		-- Fall back to empty facts and behavior context when hooks fail so tree execution can still continue.
		Facts = {},
		BehaviorContext = {},
		Services = hookContext.Services,
	}
end

--[=[
	@private
	Pushes a runtime failure into the defect list and optional error sink.
	@within AiRuntimeService
	@param defects { TErrorSinkPayload }
	@param stage string
	@param entityState TEntityFrameState
	@param errorType string
	@param errorMessage string
	@param details { [string]: any }?
]=]
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

--[=[
	@private
	Pushes one defect payload and forwards it to the optional error sink.
	@within AiRuntimeService
	@param defects { TErrorSinkPayload }
	@param payload TErrorSinkPayload
]=]
function Runtime:_PushDefect(defects: { TErrorSinkPayload }, payload: TErrorSinkPayload)
	table.insert(defects, payload)

	if self._errorSink ~= nil then
		self._errorSink(payload)
	end
end

--[=[
	@private
	Selects the actor types for one frame from the optional frame filter or registration order.
	@within AiRuntimeService
	@param frameContext TFrameContext
	@param actorAdapters { [string]: TActorAdapter }
	@param actorOrder { string }
	@return { string }
]=]
function _ResolveActorTypes(
	frameContext: TFrameContext,
	actorAdapters: { [string]: TActorAdapter },
	actorOrder: { string }
): { string }
	-- An explicit frame filter wins over registration order when the caller only wants a subset of actor types.
	if frameContext.ActorTypes == nil then
		return actorOrder
	end

	for _, actorType in ipairs(frameContext.ActorTypes) do
		-- Validate every requested actor type before the frame starts, so missing adapters fail fast.
		assert(actorAdapters[actorType] ~= nil, ("AiRuntime frame requested unknown actor type '%s'"):format(actorType))
	end

	return frameContext.ActorTypes
end

--[=[
	@private
	Builds the behavior-tree execution context from hook output and adapter state.
	@within AiRuntimeService
	@param entity number
	@param actorType string
	@param adapter TActorAdapter
	@param hookOutcome THookOutcome
	@return { [string]: any }
]=]
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
			-- Keep hook-provided fields, but never let them overwrite the reserved tree keys.
			treeContext[key] = value
		end
	end

	return treeContext
end

--[=[
	@private
	Normalizes an adapter action-state snapshot into the shape expected by the shared BehaviorSystem boundary.
	@within AiRuntimeService
	@param actionState TActionState?
	@return TActionState
]=]
function _CloneActionState(actionState: TActionState?): TActionState
	if actionState == nil then
		-- A missing state is normalized to the idle shape expected by the shared BehaviorSystem boundary.
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

	-- Clone the known fields so later runtime phases mutate a local copy instead of the adapter payload.
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

--[=[
	@private
	Returns the optional adapter label used in defect payloads.
	@within AiRuntimeService
	@param adapter TActorAdapter
	@return string?
]=]
function _GetActorLabel(adapter: TActorAdapter): string?
	if adapter.GetActorLabel == nil then
		return nil
	end

	return adapter:GetActorLabel()
end

--[=[
	@private
	Builds one immutable cleanup result payload.
	@within AiRuntimeService
	@param actorType string
	@param entity number
	@param cleanupKind TCleanupKind
	@param status string
	@param defect TErrorSinkPayload?
	@return TCleanupResult
]=]
function _BuildCleanupResult(
	actorType: string,
	entity: number,
	cleanupKind: TCleanupKind,
	status: string,
	defect: TErrorSinkPayload?
): TCleanupResult
	return {
		ActorType = actorType,
		Entity = entity,
		CleanupKind = cleanupKind,
		Status = status,
		Defect = defect,
	}
end

return table.freeze(Runtime)
