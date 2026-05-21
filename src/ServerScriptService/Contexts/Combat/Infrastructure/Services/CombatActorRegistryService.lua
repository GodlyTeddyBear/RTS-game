--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local ActorRegistryBase = require(ServerStorage.Utilities.ContextUtilities.ActorRegistryBase)
local Result = require(ReplicatedStorage.Utilities.Result)
local CombatTypes = require(ReplicatedStorage.Contexts.Combat.Types.CombatTypes)
local Errors = require(script.Parent.Parent.Parent.Errors)

type CombatActorTypePayload = CombatTypes.CombatActorTypePayload
type CombatActorPayload = CombatTypes.CombatActorPayload
type CombatActorRecord = CombatTypes.CombatActorRecord
type CombatActionState = CombatTypes.CombatActionState

local Err = Result.Err

--[=[
	@class CombatActorRegistryService
	Owns combat actor registration, runtime snapshots, and adapter callbacks for combat behavior.
	@server
]=]
local CombatActorRegistryService = {}
CombatActorRegistryService.__index = CombatActorRegistryService
setmetatable(CombatActorRegistryService, ActorRegistryBase)

--[=[
	@within CombatActorRegistryService
	Creates a new actor registry service with the shared registry base state.
	@return CombatActorRegistryService -- Service instance used to track combat actors.
]=]
function CombatActorRegistryService.new()
	local self = ActorRegistryBase.new()
	return setmetatable(self, CombatActorRegistryService)
end

--[=[
	@within CombatActorRegistryService
	Resolves the registry dependencies used by the combat actor registry service.
	@param _registry any -- Registry instance supplied by the context bootstrap.
	@param _name string -- Registry key used to register the service.
]=]
function CombatActorRegistryService:Init(_registry: any, _name: string) end

--[=[
	@within CombatActorRegistryService
	Unregisters one actor when its runtime handle is removed.
	@param actorHandle string -- Actor handle to unregister.
	@return Result.Result<boolean> -- Whether the actor was removed successfully.
]=]
function CombatActorRegistryService:NotifyActorRemoved(actorHandle: string): Result.Result<boolean>
	return self:UnregisterActor(actorHandle)
end

--[=[
	@within CombatActorRegistryService
	Returns whether any actor types are currently registered.
	@return boolean -- Whether the registry contains at least one actor type.
]=]
function CombatActorRegistryService:HasActorTypes(): boolean
	return next(self._actorTypes) ~= nil
end

--[=[
	@within CombatActorRegistryService
	Returns the current action state for one actor handle.
	@param actorHandle string -- Actor handle to read.
	@return CombatActionState? -- Cloned action state or `nil` when the handle is unknown.
]=]
function CombatActorRegistryService:GetActionStateByHandle(actorHandle: string): CombatActionState?
	local runtimeId = self._runtimeIdsByHandle[actorHandle]
	if runtimeId == nil then
		return nil
	end

	return self:GetActionState(runtimeId)
end

--[=[
	@within CombatActorRegistryService
	Returns the compiled behavior tree stored for one runtime id.
	@param runtimeId number -- Runtime id to read.
	@return any? -- Compiled behavior tree or `nil` when the runtime id is unknown.
]=]
function CombatActorRegistryService:GetCompiledBehaviorTree(runtimeId: number): any?
	local record = self._recordsByRuntimeId[runtimeId]
	return if record ~= nil then record.BehaviorTree else nil
end

--[=[
	@within CombatActorRegistryService
	Returns a cloned snapshot of one actor's action state.
	@param runtimeId number -- Runtime id to read.
	@return CombatActionState? -- Cloned action state or `nil` when the runtime id is unknown.
]=]
function CombatActorRegistryService:GetActionState(runtimeId: number): CombatActionState?
	local record = self._recordsByRuntimeId[runtimeId]
	return if record ~= nil then table.clone(record.ActionState) else nil
end

--[=[
	@within CombatActorRegistryService
	Replaces one actor's action state and notifies listeners of the change.
	@param runtimeId number -- Runtime id to update.
	@param actionState CombatActionState -- New action state snapshot.
]=]
function CombatActorRegistryService:SetActionState(runtimeId: number, actionState: CombatActionState)
	local record = self._recordsByRuntimeId[runtimeId]
	if record == nil then
		return
	end

	-- Normalize partial updates so the runtime always sees a complete action snapshot.
	record.ActionState = {
		CurrentActionId = actionState.CurrentActionId,
		ActionState = actionState.ActionState or "Idle",
		ActionData = actionState.ActionData,
		PendingActionId = actionState.PendingActionId,
		PendingActionData = actionState.PendingActionData,
		StartedAt = actionState.StartedAt,
		FinishedAt = actionState.FinishedAt,
	}

	self:_NotifyActionStateChanged(record)
end

--[=[
	@within CombatActorRegistryService
	Resets one actor's action state to the default idle snapshot.
	@param runtimeId number -- Runtime id to update.
]=]
function CombatActorRegistryService:ClearActionState(runtimeId: number)
	local record = self._recordsByRuntimeId[runtimeId]
	if record == nil then
		return
	end

	record.ActionState = self:_BuildDefaultActionState()
	self:_NotifyActionStateChanged(record)
end

--[=[
	@within CombatActorRegistryService
	Stores the next pending action for one actor runtime.
	@param runtimeId number -- Runtime id to update.
	@param actionId string -- Pending action identifier.
	@param actionData any? -- Optional action payload.
]=]
function CombatActorRegistryService:SetPendingAction(runtimeId: number, actionId: string, actionData: any?)
	local record = self._recordsByRuntimeId[runtimeId]
	if record == nil then
		return
	end

	-- Only trace the first queued base attack so the log stays focused on state changes.
	if actionId == "AttackBase" and record.ActionState.PendingActionId ~= "AttackBase" then
		Result.MentionEvent("Combat:ActorRegistry", "Queued pending base attack action", {
			ActorType = record.ActorType,
			ActorHandle = record.ActorHandle,
			RuntimeId = runtimeId,
			CurrentActionId = record.ActionState.CurrentActionId,
		})
	end

	-- Store the pending action separately so the runtime can commit it on the next tick.
	record.ActionState.PendingActionId = actionId
	record.ActionState.PendingActionData = actionData
end

--[=[
	@within CombatActorRegistryService
	Updates the last time one actor was ticked by the runtime.
	@param runtimeId number -- Runtime id to update.
	@param currentTime number -- Current runtime time in seconds.
]=]
function CombatActorRegistryService:UpdateLastTickTime(runtimeId: number, currentTime: number)
	local record = self._recordsByRuntimeId[runtimeId]
	if record == nil then
		return
	end

	record.LastTickTime = currentTime
end

--[=[
	@within CombatActorRegistryService
	Returns whether the runtime should evaluate the actor on the current frame.
	@param runtimeId number -- Runtime id to check.
	@param currentTime number -- Current runtime time in seconds.
	@return boolean -- Whether the actor is eligible for evaluation.
]=]
function CombatActorRegistryService:ShouldEvaluate(runtimeId: number, currentTime: number): boolean
	local record = self._recordsByRuntimeId[runtimeId]
	if record == nil then
		return false
	end

	-- Committed actors have already finished their decision for this frame.
	if record.ActionState.ActionState == "Committed" then
		return false
	end

	-- Enforce the actor-specific tick interval so faster callers do not over-evaluate it.
	return currentTime - record.LastTickTime >= record.TickInterval
end

--[=[
	@within CombatActorRegistryService
	Builds the facts payload passed into an actor adapter for one runtime tick.
	@param runtimeId number -- Runtime id to evaluate.
	@param currentTime number -- Current runtime time in seconds.
	@return { [string]: any } -- Adapter facts or an empty table when the adapter fails.
]=]
function CombatActorRegistryService:BuildFacts(runtimeId: number, currentTime: number): { [string]: any }
	local record = self._recordsByRuntimeId[runtimeId]
	if record == nil then
		return {}
	end

	-- Keep adapter failures isolated so one bad actor cannot break the registry tick.
	local didBuild, facts = pcall(record.Adapter.BuildFacts, currentTime)
	if not didBuild or type(facts) ~= "table" then
		-- Reject malformed adapter output and fall back to an empty fact set.
		Result.MentionError("Combat:ActorRegistry", "Actor facts adapter failed", {
			ActorType = record.ActorType,
			ActorHandle = record.ActorHandle,
			RuntimeId = runtimeId,
			CauseMessage = facts,
		}, "ActorFactsAdapterFailed")
		return {}
	end

	return facts
end

--[=[
	@within CombatActorRegistryService
	Builds the services payload passed into an actor adapter for one runtime tick.
	@param runtimeId number -- Runtime id to evaluate.
	@param currentTime number -- Current runtime time in seconds.
	@return { [string]: any } -- Adapter services or an empty table when the adapter fails.
]=]
function CombatActorRegistryService:BuildServices(
	runtimeId: number,
	currentTime: number,
	tickId: number?,
	frameContext: any?
): { [string]: any }
	local record = self._recordsByRuntimeId[runtimeId]
	if record == nil then
		return {}
	end

	-- Keep adapter failures isolated so one bad actor cannot break the service tick.
	local didBuild, services = pcall(record.Adapter.BuildServices, currentTime, tickId, frameContext)
	if not didBuild or type(services) ~= "table" then
		-- Reject malformed adapter output and fall back to an empty service set.
		Result.MentionError("Combat:ActorRegistry", "Actor services adapter failed", {
			ActorType = record.ActorType,
			ActorHandle = record.ActorHandle,
			RuntimeId = runtimeId,
			CauseMessage = services,
		}, "ActorServicesAdapterFailed")
		return {}
	end

	return services
end

--[=[
	@within CombatActorRegistryService
	Returns the actor label reported by the adapter for one runtime id.
	@param runtimeId number -- Runtime id to read.
	@return string? -- Actor label or `nil` when the adapter does not expose one.
]=]
function CombatActorRegistryService:GetActorLabel(runtimeId: number): string?
	local record = self._recordsByRuntimeId[runtimeId]
	if record == nil or record.Adapter.GetActorLabel == nil then
		return nil
	end

	-- Labels are optional, so failures should degrade to nil instead of surfacing noise.
	local didResolve, label = pcall(record.Adapter.GetActorLabel)
	if not didResolve or (label ~= nil and type(label) ~= "string") then
		return nil
	end

	return label
end

--[=[
	@within CombatActorRegistryService
	Invokes the adapter cancellation callback for one actor runtime.
	@param runtimeId number -- Runtime id to cancel.
]=]
function CombatActorRegistryService:CancelActor(runtimeId: number)
	local record = self._recordsByRuntimeId[runtimeId]
	if record == nil or record.Adapter.OnCancel == nil then
		return
	end

	-- Cancellation is best-effort; the runtime should continue even if the callback fails.
	local didCancel = pcall(record.Adapter.OnCancel)
	if not didCancel then
		Result.MentionError("Combat:ActorRegistry", "Actor cancel callback failed", {
			ActorType = record.ActorType,
			ActorHandle = record.ActorHandle,
			RuntimeId = runtimeId,
		}, "ActorCancelCallbackFailed")
	end
end

--[=[
	@within CombatActorRegistryService
	Forwards one action result to the adapter callback for the actor runtime.
	@param runtimeId number -- Runtime id to notify.
	@param actionResult any -- Action result payload produced by the runtime.
]=]
function CombatActorRegistryService:NotifyActionResult(runtimeId: number, actionResult: any)
	local record = self._recordsByRuntimeId[runtimeId]
	if record == nil or record.Adapter.OnActionResult == nil then
		return
	end

	-- Result delivery is best-effort so runtime output does not depend on one adapter.
	local didNotify = pcall(record.Adapter.OnActionResult, actionResult)
	if not didNotify then
		Result.MentionError("Combat:ActorRegistry", "Actor action-result callback failed", {
			ActorType = record.ActorType,
			ActorHandle = record.ActorHandle,
			RuntimeId = runtimeId,
		}, "ActorActionResultCallbackFailed")
	end
end

function CombatActorRegistryService:_ValidateActorTypePayload(payload: CombatActorTypePayload): Result.Err?
	-- Reject malformed actor-type tables before they are frozen into the registry.
	if type(payload) ~= "table" then
		return Err("InvalidActorTypePayload", Errors.INVALID_ACTOR_TYPE_PAYLOAD)
	end

	-- Actor type names must be present so the runtime can namespace the behavior hooks.
	if type(payload.ActorType) ~= "string" or payload.ActorType == "" then
		return Err("InvalidActorTypePayload", Errors.INVALID_ACTOR_TYPE_PAYLOAD)
	end

	-- The runtime merges these registries later, so each table must exist up front.
	if
		type(payload.Conditions) ~= "table"
		or type(payload.Commands) ~= "table"
		or type(payload.Executors) ~= "table"
	then
		return Err("InvalidActorTypePayload", Errors.INVALID_ACTOR_TYPE_PAYLOAD, {
			ActorType = payload.ActorType,
		})
	end

	return nil
end

function CombatActorRegistryService:_ValidateActorPayload(payload: CombatActorPayload): Result.Err?
	-- Reject malformed actor payloads before the runtime ever builds a record from them.
	if type(payload) ~= "table" then
		return Err("InvalidActorPayload", Errors.INVALID_ACTOR_PAYLOAD)
	end

	-- Actor type and handle together form the registry identity for the runtime record.
	if type(payload.ActorType) ~= "string" or payload.ActorType == "" then
		return Err("InvalidActorPayload", Errors.INVALID_ACTOR_PAYLOAD)
	end

	if type(payload.ActorHandle) ~= "string" or payload.ActorHandle == "" then
		return Err("InvalidActorPayload", Errors.INVALID_ACTOR_PAYLOAD)
	end

	-- Behavior definition and tick interval are the minimum data required to schedule the actor.
	if payload.BehaviorDefinition == nil or type(payload.TickInterval) ~= "number" or payload.TickInterval <= 0 then
		return Err("InvalidActorPayload", Errors.INVALID_ACTOR_PAYLOAD, {
			ActorType = payload.ActorType,
			ActorHandle = payload.ActorHandle,
		})
	end

	local adapter = payload.Adapter
	-- The runtime depends on these adapter hooks to query, evaluate, and react to the actor.
	if
		type(adapter) ~= "table"
		or type(adapter.IsActive) ~= "function"
		or type(adapter.BuildFacts) ~= "function"
		or type(adapter.BuildServices) ~= "function"
	then
		return Err("InvalidActorPayload", Errors.INVALID_ACTOR_PAYLOAD, {
			ActorType = payload.ActorType,
			ActorHandle = payload.ActorHandle,
		})
	end

	return nil
end

function CombatActorRegistryService:_BuildStoredActorTypePayload(
	payload: CombatActorTypePayload
): CombatActorTypePayload
	-- Freeze the stored payload so runtime consumers treat the registry entry as immutable config.
	return table.freeze({
		ActorType = payload.ActorType,
		Conditions = payload.Conditions,
		Commands = payload.Commands,
		Executors = payload.Executors,
		Hooks = payload.Hooks,
		SemanticRequirements = payload.SemanticRequirements,
		RuntimeBinding = payload.RuntimeBinding,
		RuntimeOwner = payload.RuntimeOwner,
	})
end

function CombatActorRegistryService:_BuildRecordFromPayload(
	payload: CombatActorPayload,
	runtimeId: number,
	buildContext: any?
): CombatActorRecord
	-- Store the compiled tree and adapter together so the runtime can evaluate the actor in place.
	return {
		RuntimeId = runtimeId,
		ActorType = payload.ActorType,
		ActorHandle = payload.ActorHandle,
		BehaviorTree = buildContext,
		TickInterval = payload.TickInterval,
		LastTickTime = 0,
		ActionState = self:_BuildDefaultActionState(),
		Adapter = payload.Adapter,
	}
end

function CombatActorRegistryService:_BuildDefaultActionState(): CombatActionState
	-- Start every actor in a neutral idle state until the runtime assigns a command.
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

function CombatActorRegistryService:_IsRecordActive(record: CombatActorRecord): boolean
	-- Active state is delegated to the adapter so the registry stays generic.
	local didCheck, isActive = pcall(record.Adapter.IsActive)
	if not didCheck then
		Result.MentionError("Combat:ActorRegistry", "Actor active adapter failed", {
			ActorType = record.ActorType,
			ActorHandle = record.ActorHandle,
			RuntimeId = record.RuntimeId,
			CauseMessage = isActive,
		}, "ActorActiveAdapterFailed")
		return false
	end

	return isActive == true
end

function CombatActorRegistryService:_NotifyActionStateChanged(record: CombatActorRecord)
	if record.Adapter.OnActionStateChanged == nil then
		return
	end

	-- Send a clone so listeners cannot mutate the authoritative registry snapshot.
	local didNotify = pcall(record.Adapter.OnActionStateChanged, table.clone(record.ActionState))
	if not didNotify then
		Result.MentionError("Combat:ActorRegistry", "Actor action-state callback failed", {
			ActorType = record.ActorType,
			ActorHandle = record.ActorHandle,
			RuntimeId = record.RuntimeId,
		}, "ActorActionStateCallbackFailed")
	end
end

function CombatActorRegistryService:_InvokeRemovedCallback(record: CombatActorRecord)
	if record.Adapter.OnRemoved == nil then
		return
	end

	-- Removal callbacks are advisory; cleanup should still finish if the adapter fails.
	local didRemove = pcall(record.Adapter.OnRemoved)
	if not didRemove then
		Result.MentionError("Combat:ActorRegistry", "Actor removal callback failed", {
			ActorType = record.ActorType,
			ActorHandle = record.ActorHandle,
		}, "ActorRemovalCallbackFailed")
	end
end

return CombatActorRegistryService
