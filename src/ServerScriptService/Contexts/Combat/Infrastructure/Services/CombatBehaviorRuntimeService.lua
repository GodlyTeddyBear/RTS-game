--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AI = require(ReplicatedStorage.Utilities.AI)
local Result = require(ReplicatedStorage.Utilities.Result)
local Errors = require(script.Parent.Parent.Parent.Errors)
local ActorAdapterHook = require(script.Parent.Parent.BehaviorSystem.Hooks.ActorAdapterHook)

local Ok = Result.Ok
local Err = Result.Err

type TMergedRuntimeInputs = {
	Conditions: { [string]: (any?) -> any },
	Commands: { [string]: (any?) -> any },
	Executors: { [string]: any },
	Hooks: { any },
}

local CombatBehaviorRuntimeService = {}
CombatBehaviorRuntimeService.__index = CombatBehaviorRuntimeService

function CombatBehaviorRuntimeService.new()
	local self = setmetatable({}, CombatBehaviorRuntimeService)
	self._runtime = nil
	self._actorRegistryService = nil
	return self
end

function CombatBehaviorRuntimeService:Init(registry: any, _name: string)
	self._actorRegistryService = registry:Get("CombatActorRegistryService")
end

function CombatBehaviorRuntimeService:StartRuntime(): Result.Result<boolean>
	if self._actorRegistryService:IsRuntimeStarted() then
		return Err("RuntimeAlreadyStarted", Errors.RUNTIME_ALREADY_STARTED)
	end

	local actorTypePayloads = self._actorRegistryService:GetActorTypePayloads()
	if #actorTypePayloads == 0 then
		return Err("RuntimeStartFailed", Errors.RUNTIME_START_FAILED, {
			Reason = "NoActorTypesRegistered",
		})
	end

	local actorTypeNames = {}
	for _, actorTypePayload in ipairs(actorTypePayloads) do
		table.insert(actorTypeNames, actorTypePayload.ActorType)
	end

	Result.MentionEvent("Combat:BehaviorRuntime", "Starting combat runtime", {
		ActorTypeCount = #actorTypePayloads,
		ActorTypes = actorTypeNames,
	})

	local buildStage = "BuildRuntimeInputs"
	local didBuild, buildResult = pcall(function()
		buildStage = "BuildRuntimeInputs"
		local mergedInputs = self:_BuildRuntimeInputs()
		buildStage = "CreateRuntime"
		local runtime = AI.CreateRuntime({
			Conditions = mergedInputs.Conditions,
			Commands = mergedInputs.Commands,
			Hooks = mergedInputs.Hooks,
			ErrorSink = function(payload: any)
				local actorType = tostring(payload.ActorType or "UnknownActorType")
				local stage = tostring(payload.Stage or "UnknownStage")
				local errorType = tostring(payload.ErrorType or "UnknownError")
				local causeMessage = tostring(payload.ErrorMessage or "No cause message")
				local actorDescriptor = if payload.ActorLabel ~= nil
					then string.format("%s (%s)", actorType, tostring(payload.ActorLabel))
					else actorType
				local defectMessage = string.format(
					"AI defect [%s] %s [%s]: %s",
					stage,
					actorDescriptor,
					errorType,
					causeMessage
				)
				Result.MentionError(
					"Combat:BehaviorRuntime",
					defectMessage,
					{
						Summary = defectMessage,
						RuntimeStage = stage,
						Actor = actorDescriptor,
						ActorType = actorType,
						ActorLabel = payload.ActorLabel,
						Entity = payload.Entity,
						ErrorType = errorType,
						CauseMessage = causeMessage,
						DefectDetails = payload.Details,
					},
					payload.ErrorType
				)
			end,
		})

		buildStage = "RegisterExecutors"
		runtime:RegisterActions(mergedInputs.Executors)
		for _, actorTypePayload in ipairs(actorTypePayloads) do
			buildStage = "RegisterActorType:" .. actorTypePayload.ActorType
			runtime:RegisterActorType(actorTypePayload.ActorType, self:_CreateRegistryAdapter(actorTypePayload.ActorType))
		end

		return runtime
	end)

	if not didBuild then
		Result.MentionError("Combat:BehaviorRuntime", "Combat runtime build failed", {
			Stage = buildStage,
			ActorTypeCount = #actorTypePayloads,
			ActorTypes = actorTypeNames,
			CauseMessage = buildResult,
		}, "RuntimeStartFailed")
		return Err("RuntimeStartFailed", Errors.RUNTIME_START_FAILED, {
			Stage = buildStage,
			CauseMessage = buildResult,
		})
	end

	self._runtime = buildResult
	self._actorRegistryService:SetRuntimeStarted(true)

	Result.MentionSuccess("Combat:BehaviorRuntime", "Combat runtime started", {
		ActorTypeCount = #actorTypePayloads,
		ActorTypes = actorTypeNames,
	})

	local queueResult = self:_RegisterQueuedActors()
	if not queueResult.success then
		self._runtime = nil
		self._actorRegistryService:SetRuntimeStarted(false)
		return queueResult
	end

	return Ok(true)
end

function CombatBehaviorRuntimeService:StopRuntime(): Result.Result<boolean>
	if not self._actorRegistryService:IsRuntimeStarted() then
		return Ok(false)
	end

	self._runtime = nil
	self._actorRegistryService:SetRuntimeStarted(false)

	return Ok(true)
end

function CombatBehaviorRuntimeService:BuildTree(definition: any): Result.Result<any>
	if self._runtime == nil then
		return Err("RuntimeNotStarted", Errors.RUNTIME_NOT_STARTED)
	end

	local didBuild, tree = pcall(function()
		return self._runtime:BuildTree(definition)
	end)

	if not didBuild then
		return Err("RuntimeStartFailed", Errors.RUNTIME_START_FAILED, {
			CauseMessage = tree,
		})
	end

	return Ok(tree)
end

function CombatBehaviorRuntimeService:RunFrame(frameContext: any): any
	if self._runtime == nil then
		return {
			EntityResults = {},
			Defects = {},
		}
	end

	return self._runtime:RunFrame(frameContext)
end

function CombatBehaviorRuntimeService:CancelActorAction(actorType: string, runtimeId: number, frameContext: any): any
	if self._runtime == nil then
		return nil
	end

	self._actorRegistryService:CancelActor(runtimeId)
	return self._runtime:CancelActorAction(actorType, runtimeId, frameContext)
end

function CombatBehaviorRuntimeService:HandleActorDeath(actorType: string, runtimeId: number, frameContext: any): any
	if self._runtime == nil then
		return nil
	end

	return self._runtime:HandleActorDeath(actorType, runtimeId, frameContext)
end

function CombatBehaviorRuntimeService:GetExecutor(actionId: string)
	if self._runtime == nil then
		return nil
	end

	return self._runtime:GetExecutor(actionId)
end

function CombatBehaviorRuntimeService:_RegisterQueuedActors(): Result.Result<boolean>
	local pendingPayloads = self._actorRegistryService:GetPendingActorPayloads()
	local payloadsByHandle = {}
	local registeredHandles = {}

	for _, payload in ipairs(pendingPayloads) do
		payloadsByHandle[payload.ActorHandle] = payload

		local behaviorTreeResult = self:BuildTree(payload.BehaviorDefinition)
		if not behaviorTreeResult.success then
			Result.MentionError("Combat:BehaviorRuntime", "Queued actor behavior tree build failed", {
				Stage = "BuildTree",
				ActorType = payload.ActorType,
				ActorHandle = payload.ActorHandle,
				CauseType = behaviorTreeResult.type,
				CauseMessage = behaviorTreeResult.message,
				Details = behaviorTreeResult.data,
			}, behaviorTreeResult.type)
			self:_RollbackQueuedActorStartup(payloadsByHandle, registeredHandles)
			return behaviorTreeResult
		end

		local registerResult = self._actorRegistryService:RegisterActor(payload, behaviorTreeResult.value)
		if not registerResult.success then
			Result.MentionError("Combat:BehaviorRuntime", "Queued actor registration failed", {
				Stage = "RegisterQueuedActor",
				ActorType = payload.ActorType,
				ActorHandle = payload.ActorHandle,
				CauseType = registerResult.type,
				CauseMessage = registerResult.message,
				Details = registerResult.data,
			}, registerResult.type)
			self:_RollbackQueuedActorStartup(payloadsByHandle, registeredHandles)
			return registerResult
		end

		table.insert(registeredHandles, payload.ActorHandle)
		self._actorRegistryService:RemovePendingActorPayload(payload.ActorHandle)
	end

	return Ok(true)
end

function CombatBehaviorRuntimeService:_RollbackQueuedActorStartup(
	payloadsByHandle: { [string]: any },
	registeredHandles: { string }
)
	for _, actorHandle in ipairs(registeredHandles) do
		self._actorRegistryService:DiscardActor(actorHandle)

		local payload = payloadsByHandle[actorHandle]
		if payload ~= nil then
			self._actorRegistryService:QueueActor(payload)
		end
	end
end

function CombatBehaviorRuntimeService:_BuildRuntimeInputs(): TMergedRuntimeInputs
	local mergedInputs: TMergedRuntimeInputs = {
		Conditions = {},
		Commands = {},
		Executors = {},
		Hooks = {
			ActorAdapterHook,
		},
	}

	for _, actorTypePayload in ipairs(self._actorRegistryService:GetActorTypePayloads()) do
		self:_MergeNamedRegistry(mergedInputs.Conditions, actorTypePayload.Conditions, actorTypePayload.ActorType, "Condition")
		self:_MergeNamedRegistry(mergedInputs.Commands, actorTypePayload.Commands, actorTypePayload.ActorType, "Command")
		self:_MergeNamedRegistry(mergedInputs.Executors, actorTypePayload.Executors, actorTypePayload.ActorType, "Executor")
		self:_AppendHooks(mergedInputs.Hooks, actorTypePayload.Hooks)
	end

	return mergedInputs
end

function CombatBehaviorRuntimeService:_MergeNamedRegistry(
	target: { [string]: any },
	source: { [string]: any },
	actorType: string,
	registryLabel: string
)
	for key, value in pairs(source) do
		assert(
			target[key] == nil,
			string.format(
				"Combat %s '%s' from actor type '%s' is registered more than once; namespace actor actions by context",
				registryLabel,
				key,
				actorType
			)
		)
		target[key] = value
	end
end

function CombatBehaviorRuntimeService:_AppendHooks(target: { any }, hooks: { any }?)
	if hooks == nil then
		return
	end

	for _, hook in ipairs(hooks) do
		table.insert(target, hook)
	end
end

function CombatBehaviorRuntimeService:_CreateRegistryAdapter(actorType: string): any
	return AI.CreateAdapter({
		ActorLabel = actorType,
		QueryActiveEntities = function(_frameContext: any): { number }
			return self._actorRegistryService:QueryActiveRuntimeIds(actorType)
		end,
		GetCompiledBehaviorTree = function(runtimeId: number): any?
			return self._actorRegistryService:GetCompiledBehaviorTree(runtimeId)
		end,
		GetActionState = function(runtimeId: number): any?
			return self._actorRegistryService:GetActionState(runtimeId)
		end,
		SetActionState = function(runtimeId: number, actionState: any)
			self._actorRegistryService:SetActionState(runtimeId, actionState)
		end,
		ClearActionState = function(runtimeId: number)
			self._actorRegistryService:ClearActionState(runtimeId)
		end,
		SetPendingAction = function(runtimeId: number, actionId: string, actionData: any?)
			self._actorRegistryService:SetPendingAction(runtimeId, actionId, actionData)
		end,
		UpdateLastTickTime = function(runtimeId: number, currentTime: number)
			self._actorRegistryService:UpdateLastTickTime(runtimeId, currentTime)
		end,
		ShouldEvaluate = function(runtimeId: number, currentTime: number): boolean
			return self._actorRegistryService:ShouldEvaluate(runtimeId, currentTime)
		end,
	})
end

return CombatBehaviorRuntimeService
