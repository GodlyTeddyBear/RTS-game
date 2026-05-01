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

--[=[
	@class CombatBehaviorRuntimeService
	Builds and runs the shared AI runtime used by combat actors.
	@server
]=]
local CombatBehaviorRuntimeService = {}
CombatBehaviorRuntimeService.__index = CombatBehaviorRuntimeService

--[=[
	@within CombatBehaviorRuntimeService
	Creates a new runtime service with no active AI runtime.
	@return CombatBehaviorRuntimeService -- Service instance used to manage combat AI runtime state.
]=]
function CombatBehaviorRuntimeService.new()
	local self = setmetatable({}, CombatBehaviorRuntimeService)
	self._runtime = nil
	self._actorRegistryService = nil
	return self
end

--[=[
	@within CombatBehaviorRuntimeService
	Resolves the actor registry service dependency used to build and drive the runtime.
	@param registry any -- Registry instance supplied by the context bootstrap.
	@param _name string -- Registry key used to register the service.
]=]
function CombatBehaviorRuntimeService:Init(registry: any, _name: string)
	self._actorRegistryService = registry:Get("CombatActorRegistryService")
end

--[=[
	@within CombatBehaviorRuntimeService
	Builds and starts the combat AI runtime, then registers any queued actor payloads.
	@return Result.Result<boolean> -- Whether the runtime started successfully.
]=]
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
		-- Assemble the runtime inputs before constructing the AI runtime.
		buildStage = "BuildRuntimeInputs"
		local mergedInputs = self:_BuildRuntimeInputs()
		-- Create the runtime with the merged registry inputs and error sink.
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

		-- Register the shared executors and then the actor-specific adapters.
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

--[=[
	@within CombatBehaviorRuntimeService
	Stops the active combat AI runtime if one is running.
	@return Result.Result<boolean> -- Whether the runtime transitioned to a stopped state.
]=]
function CombatBehaviorRuntimeService:StopRuntime(): Result.Result<boolean>
	if not self._actorRegistryService:IsRuntimeStarted() then
		return Ok(false)
	end

	self._runtime = nil
	self._actorRegistryService:SetRuntimeStarted(false)

	return Ok(true)
end

--[=[
	@within CombatBehaviorRuntimeService
	Builds one behavior tree through the active runtime.
	@param definition any -- Behavior tree definition to compile.
	@return Result.Result<any> -- Compiled tree or a typed runtime error.
]=]
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

--[=[
	@within CombatBehaviorRuntimeService
	Runs one combat frame through the active runtime.
	@param frameContext any -- Runtime frame context produced by the combat loop.
	@return any -- Runtime frame results or an empty result payload when stopped.
]=]
function CombatBehaviorRuntimeService:RunFrame(frameContext: any): any
	if self._runtime == nil then
		return {
			EntityResults = {},
			Defects = {},
		}
	end

	return self._runtime:RunFrame(frameContext)
end

--[=[
	@within CombatBehaviorRuntimeService
	Cancels one actor action through the runtime after notifying the registry service.
	@param actorType string -- Actor type to route through the runtime.
	@param runtimeId number -- Runtime id to cancel.
	@param frameContext any -- Runtime frame context for the cancellation.
	@return any -- Runtime cancellation payload or `nil` when the runtime is stopped.
]=]
function CombatBehaviorRuntimeService:CancelActorAction(actorType: string, runtimeId: number, frameContext: any): any
	if self._runtime == nil then
		return nil
	end

	self._actorRegistryService:CancelActor(runtimeId)
	return self._runtime:CancelActorAction(actorType, runtimeId, frameContext)
end

--[=[
	@within CombatBehaviorRuntimeService
	Forwards one actor death event to the active runtime.
	@param actorType string -- Actor type to route through the runtime.
	@param runtimeId number -- Runtime id that died.
	@param frameContext any -- Runtime frame context for the death event.
	@return any -- Runtime death payload or `nil` when the runtime is stopped.
]=]
function CombatBehaviorRuntimeService:HandleActorDeath(actorType: string, runtimeId: number, frameContext: any): any
	if self._runtime == nil then
		return nil
	end

	return self._runtime:HandleActorDeath(actorType, runtimeId, frameContext)
end

--[=[
	@within CombatBehaviorRuntimeService
	Returns the executor registered for one action id.
	@param actionId string -- Action identifier to look up.
	@return any -- Executor entry or `nil` when the runtime is stopped.
]=]
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
		-- Keep the original payload by handle so failed startup can restore it exactly.
		payloadsByHandle[payload.ActorHandle] = payload

		-- Compile the behavior tree first; registration should only happen once the tree is valid.
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

		-- Register the actor after the tree exists so the runtime never sees a half-built actor.
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

		-- Track successful registrations so a later failure can unwind only the new actors.
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
		-- Discard the runtime actor before re-queueing its payload to keep the registry consistent.
		self._actorRegistryService:DiscardActor(actorHandle)

		local payload = payloadsByHandle[actorHandle]
		if payload ~= nil then
			-- Restore the exact payload so a retry can reuse the original startup data.
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

	-- Merge all actor registrations into a single runtime table so the AI runtime can stay generic.
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
		-- Namespaces must stay unique so one actor type cannot silently override another.
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

	-- Append hooks in registration order so actor-specific behavior layers on top of the base hook.
	for _, hook in ipairs(hooks) do
		table.insert(target, hook)
	end
end

function CombatBehaviorRuntimeService:_CreateRegistryAdapter(actorType: string): any
	return AI.CreateAdapter({
		ActorLabel = actorType,
		-- Route runtime queries through the registry so the adapter stays stateless.
		QueryActiveEntities = function(_frameContext: any): { number }
			return self._actorRegistryService:QueryActiveRuntimeIds(actorType)
		end,
		-- Expose the compiled tree so the AI runtime can evaluate the actor's current behavior.
		GetCompiledBehaviorTree = function(runtimeId: number): any?
			return self._actorRegistryService:GetCompiledBehaviorTree(runtimeId)
		end,
		-- Read and write action state through the registry to keep the snapshot authoritative.
		GetActionState = function(runtimeId: number): any?
			return self._actorRegistryService:GetActionState(runtimeId)
		end,
		SetActionState = function(runtimeId: number, actionState: any)
			self._actorRegistryService:SetActionState(runtimeId, actionState)
		end,
		-- Clear the stored action state when the runtime finishes or aborts a decision.
		ClearActionState = function(runtimeId: number)
			self._actorRegistryService:ClearActionState(runtimeId)
		end,
		-- Keep pending actions in the registry until the runtime commits them.
		SetPendingAction = function(runtimeId: number, actionId: string, actionData: any?)
			self._actorRegistryService:SetPendingAction(runtimeId, actionId, actionData)
		end,
		-- Track the last tick time so the registry can enforce per-actor cadence.
		UpdateLastTickTime = function(runtimeId: number, currentTime: number)
			self._actorRegistryService:UpdateLastTickTime(runtimeId, currentTime)
		end,
		-- Ask the registry whether this actor is due for evaluation on the current frame.
		ShouldEvaluate = function(runtimeId: number, currentTime: number): boolean
			return self._actorRegistryService:ShouldEvaluate(runtimeId, currentTime)
		end,
	})
end

return CombatBehaviorRuntimeService
