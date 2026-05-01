--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ActorRegistryBase = require(ReplicatedStorage.Utilities.ActorRegistryBase)
local Result = require(ReplicatedStorage.Utilities.Result)
local MiningTypes = require(ReplicatedStorage.Contexts.Mining.Types.MiningTypes)
local Errors = require(script.Parent.Parent.Parent.Errors)

type TMiningActorTypePayload = MiningTypes.TMiningActorTypePayload
type TMiningActorPayload = MiningTypes.TMiningActorPayload
type TMiningActorRecord = MiningTypes.TMiningActorRecord
type TMiningActionState = MiningTypes.TMiningActionState

local Err = Result.Err

local MiningActorRegistryService = {}
MiningActorRegistryService.__index = MiningActorRegistryService
setmetatable(MiningActorRegistryService, ActorRegistryBase)

function MiningActorRegistryService.new()
	local self = ActorRegistryBase.new()
	return setmetatable(self, MiningActorRegistryService)
end

function MiningActorRegistryService:Init(_registry: any, _name: string) end

function MiningActorRegistryService:GetActionStateByHandle(actorHandle: string): TMiningActionState?
	local runtimeId = self._runtimeIdsByHandle[actorHandle]
	if runtimeId == nil then
		return nil
	end

	return self:GetActionState(runtimeId)
end

function MiningActorRegistryService:GetCompiledBehaviorTree(runtimeId: number): any?
	local record = self._recordsByRuntimeId[runtimeId]
	return if record ~= nil then record.BehaviorTree else nil
end

function MiningActorRegistryService:GetActionState(runtimeId: number): TMiningActionState?
	local record = self._recordsByRuntimeId[runtimeId]
	return if record ~= nil then table.clone(record.ActionState) else nil
end

function MiningActorRegistryService:SetActionState(runtimeId: number, actionState: TMiningActionState)
	local record = self._recordsByRuntimeId[runtimeId]
	if record == nil then
		return
	end

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

function MiningActorRegistryService:ClearActionState(runtimeId: number)
	local record = self._recordsByRuntimeId[runtimeId]
	if record == nil then
		return
	end

	record.ActionState = self:_BuildDefaultActionState()
	self:_NotifyActionStateChanged(record)
end

function MiningActorRegistryService:SetPendingAction(runtimeId: number, actionId: string, actionData: any?)
	local record = self._recordsByRuntimeId[runtimeId]
	if record == nil then
		return
	end

	record.ActionState.PendingActionId = actionId
	record.ActionState.PendingActionData = actionData
end

function MiningActorRegistryService:UpdateLastTickTime(runtimeId: number, currentTime: number)
	local record = self._recordsByRuntimeId[runtimeId]
	if record == nil then
		return
	end

	record.LastTickTime = currentTime
end

function MiningActorRegistryService:ShouldEvaluate(runtimeId: number, currentTime: number): boolean
	local record = self._recordsByRuntimeId[runtimeId]
	if record == nil then
		return false
	end

	if record.ActionState.ActionState == "Committed" then
		return false
	end

	return currentTime - record.LastTickTime >= record.TickInterval
end

function MiningActorRegistryService:BuildFacts(runtimeId: number, currentTime: number): { [string]: any }
	local record = self._recordsByRuntimeId[runtimeId]
	if record == nil then
		return {}
	end

	local didBuild, facts = pcall(record.Adapter.BuildFacts, currentTime)
	if not didBuild or type(facts) ~= "table" then
		Result.MentionError("Mining:ActorRegistry", "Actor facts adapter failed", {
			ActorType = record.ActorType,
			ActorHandle = record.ActorHandle,
			RuntimeId = runtimeId,
			CauseMessage = facts,
		}, "ActorFactsAdapterFailed")
		return {}
	end

	return facts
end

function MiningActorRegistryService:BuildServices(runtimeId: number, currentTime: number): { [string]: any }
	local record = self._recordsByRuntimeId[runtimeId]
	if record == nil then
		return {}
	end

	local didBuild, services = pcall(record.Adapter.BuildServices, currentTime)
	if not didBuild or type(services) ~= "table" then
		Result.MentionError("Mining:ActorRegistry", "Actor services adapter failed", {
			ActorType = record.ActorType,
			ActorHandle = record.ActorHandle,
			RuntimeId = runtimeId,
			CauseMessage = services,
		}, "ActorServicesAdapterFailed")
		return {}
	end

	return services
end

function MiningActorRegistryService:GetActorLabel(runtimeId: number): string?
	local record = self._recordsByRuntimeId[runtimeId]
	if record == nil or record.Adapter.GetActorLabel == nil then
		return nil
	end

	local didResolve, label = pcall(record.Adapter.GetActorLabel)
	if not didResolve or (label ~= nil and type(label) ~= "string") then
		return nil
	end

	return label
end

function MiningActorRegistryService:CancelActor(runtimeId: number)
	local record = self._recordsByRuntimeId[runtimeId]
	if record == nil or record.Adapter.OnCancel == nil then
		return
	end

	local didCancel = pcall(record.Adapter.OnCancel)
	if not didCancel then
		Result.MentionError("Mining:ActorRegistry", "Actor cancel callback failed", {
			ActorType = record.ActorType,
			ActorHandle = record.ActorHandle,
			RuntimeId = runtimeId,
		}, "ActorCancelCallbackFailed")
	end
end

function MiningActorRegistryService:NotifyActionResult(runtimeId: number, actionResult: any)
	local record = self._recordsByRuntimeId[runtimeId]
	if record == nil or record.Adapter.OnActionResult == nil then
		return
	end

	local didNotify = pcall(record.Adapter.OnActionResult, actionResult)
	if not didNotify then
		Result.MentionError("Mining:ActorRegistry", "Actor action-result callback failed", {
			ActorType = record.ActorType,
			ActorHandle = record.ActorHandle,
			RuntimeId = runtimeId,
		}, "ActorActionResultCallbackFailed")
	end
end

function MiningActorRegistryService:_ValidateActorTypePayload(payload: TMiningActorTypePayload): Result.Err?
	if type(payload) ~= "table" then
		return Err("InvalidActorTypePayload", Errors.INVALID_ACTOR_TYPE_PAYLOAD)
	end

	if type(payload.ActorType) ~= "string" or payload.ActorType == "" then
		return Err("InvalidActorTypePayload", Errors.INVALID_ACTOR_TYPE_PAYLOAD)
	end

	if type(payload.Conditions) ~= "table" or type(payload.Commands) ~= "table" or type(payload.Executors) ~= "table" then
		return Err("InvalidActorTypePayload", Errors.INVALID_ACTOR_TYPE_PAYLOAD, {
			ActorType = payload.ActorType,
		})
	end

	return nil
end

function MiningActorRegistryService:_ValidateActorPayload(payload: TMiningActorPayload): Result.Err?
	if type(payload) ~= "table" then
		return Err("InvalidActorPayload", Errors.INVALID_ACTOR_PAYLOAD)
	end

	if type(payload.ActorType) ~= "string" or payload.ActorType == "" then
		return Err("InvalidActorPayload", Errors.INVALID_ACTOR_PAYLOAD)
	end

	if type(payload.ActorHandle) ~= "string" or payload.ActorHandle == "" then
		return Err("InvalidActorPayload", Errors.INVALID_ACTOR_PAYLOAD)
	end

	if payload.BehaviorDefinition == nil or type(payload.TickInterval) ~= "number" or payload.TickInterval <= 0 then
		return Err("InvalidActorPayload", Errors.INVALID_ACTOR_PAYLOAD, {
			ActorType = payload.ActorType,
			ActorHandle = payload.ActorHandle,
		})
	end

	local adapter = payload.Adapter
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

function MiningActorRegistryService:_BuildStoredActorTypePayload(payload: TMiningActorTypePayload): TMiningActorTypePayload
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

function MiningActorRegistryService:_BuildRecordFromPayload(
	payload: TMiningActorPayload,
	runtimeId: number,
	buildContext: any?
): TMiningActorRecord
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

function MiningActorRegistryService:_BuildDefaultActionState(): TMiningActionState
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

function MiningActorRegistryService:_IsRecordActive(record: TMiningActorRecord): boolean
	local didCheck, isActive = pcall(record.Adapter.IsActive)
	if not didCheck then
		Result.MentionError("Mining:ActorRegistry", "Actor active adapter failed", {
			ActorType = record.ActorType,
			ActorHandle = record.ActorHandle,
			RuntimeId = record.RuntimeId,
			CauseMessage = isActive,
		}, "ActorActiveAdapterFailed")
		return false
	end

	return isActive == true
end

function MiningActorRegistryService:_NotifyActionStateChanged(record: TMiningActorRecord)
	if record.Adapter.OnActionStateChanged == nil then
		return
	end

	local didNotify = pcall(record.Adapter.OnActionStateChanged, table.clone(record.ActionState))
	if not didNotify then
		Result.MentionError("Mining:ActorRegistry", "Actor action-state callback failed", {
			ActorType = record.ActorType,
			ActorHandle = record.ActorHandle,
			RuntimeId = record.RuntimeId,
		}, "ActorActionStateCallbackFailed")
	end
end

function MiningActorRegistryService:_InvokeRemovedCallback(record: TMiningActorRecord)
	if record.Adapter.OnRemoved == nil then
		return
	end

	local didRemove = pcall(record.Adapter.OnRemoved)
	if not didRemove then
		Result.MentionError("Mining:ActorRegistry", "Actor removal callback failed", {
			ActorType = record.ActorType,
			ActorHandle = record.ActorHandle,
		}, "ActorRemovalCallbackFailed")
	end
end

return MiningActorRegistryService
