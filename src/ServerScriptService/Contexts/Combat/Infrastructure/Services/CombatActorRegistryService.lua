--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Result = require(ReplicatedStorage.Utilities.Result)
local CombatTypes = require(ReplicatedStorage.Contexts.Combat.Types.CombatTypes)
local Errors = require(script.Parent.Parent.Parent.Errors)

type CombatActorTypePayload = CombatTypes.CombatActorTypePayload
type CombatActorPayload = CombatTypes.CombatActorPayload
type CombatActorRecord = CombatTypes.CombatActorRecord
type CombatActionState = CombatTypes.CombatActionState

local Ok = Result.Ok
local Err = Result.Err

local CombatActorRegistryService = {}
CombatActorRegistryService.__index = CombatActorRegistryService

function CombatActorRegistryService.new()
	local self = setmetatable({}, CombatActorRegistryService)
	self._actorTypes = {} :: { [string]: CombatActorTypePayload }
	self._recordsByRuntimeId = {} :: { [number]: CombatActorRecord }
	self._runtimeIdsByHandle = {} :: { [string]: number }
	self._runtimeIdsByActorType = {} :: { [string]: { number } }
	self._pendingActorPayloadsByHandle = {} :: { [string]: CombatActorPayload }
	self._nextRuntimeId = 0
	self._runtimeStarted = false
	return self
end

function CombatActorRegistryService:Init(_registry: any, _name: string) end

function CombatActorRegistryService:RegisterActorType(payload: CombatActorTypePayload): Result.Result<boolean>
	local validationError = self:_ValidateActorTypePayload(payload)
	if validationError ~= nil then
		return validationError
	end

	if self._runtimeStarted then
		return Err("RuntimeAlreadyStarted", Errors.RUNTIME_ALREADY_STARTED, {
			ActorType = payload.ActorType,
		})
	end

	local actorType = payload.ActorType
	if self._actorTypes[actorType] ~= nil then
		return Err("DuplicateActorType", Errors.DUPLICATE_ACTOR_TYPE, {
			ActorType = actorType,
		})
	end

	self._actorTypes[actorType] = table.freeze({
		ActorType = actorType,
		Conditions = payload.Conditions,
		Commands = payload.Commands,
		Executors = payload.Executors,
		Hooks = payload.Hooks,
		SemanticRequirements = payload.SemanticRequirements,
		RuntimeBinding = payload.RuntimeBinding,
		RuntimeOwner = payload.RuntimeOwner,
	})
	self._runtimeIdsByActorType[actorType] = {}

	return Ok(true)
end

function CombatActorRegistryService:RegisterCombatActor(
	payload: CombatActorPayload,
	behaviorTree: any
): Result.Result<string>
	local validationError = self:ValidateCombatActorPayload(payload)
	if validationError ~= nil then
		return validationError
	end

	self._nextRuntimeId += 1
	local runtimeId = self._nextRuntimeId
	local record: CombatActorRecord = {
		RuntimeId = runtimeId,
		ActorType = payload.ActorType,
		ActorHandle = payload.ActorHandle,
		BehaviorTree = behaviorTree,
		TickInterval = payload.TickInterval,
		LastTickTime = 0,
		ActionState = self:_BuildDefaultActionState(),
		Adapter = payload.Adapter,
	}

	self._recordsByRuntimeId[runtimeId] = record
	self._runtimeIdsByHandle[payload.ActorHandle] = runtimeId
	table.insert(self._runtimeIdsByActorType[payload.ActorType], runtimeId)

	return Ok(payload.ActorHandle)
end

function CombatActorRegistryService:QueueCombatActor(payload: CombatActorPayload): Result.Result<string>
	local validationError = self:ValidateCombatActorPayload(payload)
	if validationError ~= nil then
		return validationError
	end

	if self._pendingActorPayloadsByHandle[payload.ActorHandle] ~= nil then
		return Err("DuplicateActorHandle", Errors.DUPLICATE_ACTOR_HANDLE, {
			ActorType = payload.ActorType,
			ActorHandle = payload.ActorHandle,
		})
	end

	self._pendingActorPayloadsByHandle[payload.ActorHandle] = payload
	return Ok(payload.ActorHandle)
end

function CombatActorRegistryService:ConsumePendingActorPayloads(): { CombatActorPayload }
	local payloads = {}
	for _, payload in pairs(self._pendingActorPayloadsByHandle) do
		table.insert(payloads, payload)
	end
	table.sort(payloads, function(left: CombatActorPayload, right: CombatActorPayload): boolean
		return left.ActorHandle < right.ActorHandle
	end)
	table.clear(self._pendingActorPayloadsByHandle)
	return payloads
end

function CombatActorRegistryService:ValidateCombatActorPayload(payload: CombatActorPayload): Result.Err?
	local validationError = self:_ValidateActorPayload(payload)
	if validationError ~= nil then
		return validationError
	end

	if self._actorTypes[payload.ActorType] == nil then
		return Err("UnknownActorType", Errors.UNKNOWN_ACTOR_TYPE, {
			ActorType = payload.ActorType,
			ActorHandle = payload.ActorHandle,
		})
	end

	if self._runtimeIdsByHandle[payload.ActorHandle] ~= nil then
		return Err("DuplicateActorHandle", Errors.DUPLICATE_ACTOR_HANDLE, {
			ActorType = payload.ActorType,
			ActorHandle = payload.ActorHandle,
		})
	end

	if self._pendingActorPayloadsByHandle[payload.ActorHandle] ~= nil then
		return Err("DuplicateActorHandle", Errors.DUPLICATE_ACTOR_HANDLE, {
			ActorType = payload.ActorType,
			ActorHandle = payload.ActorHandle,
		})
	end

	return nil
end

function CombatActorRegistryService:UnregisterCombatActor(actorHandle: string): Result.Result<boolean>
	local runtimeId = self._runtimeIdsByHandle[actorHandle]
	if runtimeId == nil then
		if self._pendingActorPayloadsByHandle[actorHandle] ~= nil then
			self._pendingActorPayloadsByHandle[actorHandle] = nil
			return Ok(true)
		end

		return Err("UnknownActorHandle", Errors.UNKNOWN_ACTOR_HANDLE, {
			ActorHandle = actorHandle,
		})
	end

	local record = self._recordsByRuntimeId[runtimeId]
	if record ~= nil and record.Adapter.OnRemoved ~= nil then
		local didRemove = pcall(record.Adapter.OnRemoved)
		if not didRemove then
			Result.MentionError("Combat:ActorRegistry", "Actor removal callback failed", {
				ActorType = record.ActorType,
				ActorHandle = actorHandle,
			}, "ActorRemovalCallbackFailed")
		end
	end

	self:_RemoveRuntimeId(runtimeId)
	return Ok(true)
end

function CombatActorRegistryService:NotifyActorRemoved(actorHandle: string): Result.Result<boolean>
	return self:UnregisterCombatActor(actorHandle)
end

function CombatActorRegistryService:SetRuntimeStarted(isStarted: boolean)
	self._runtimeStarted = isStarted
end

function CombatActorRegistryService:IsRuntimeStarted(): boolean
	return self._runtimeStarted
end

function CombatActorRegistryService:HasActorTypes(): boolean
	return next(self._actorTypes) ~= nil
end

function CombatActorRegistryService:GetActorTypePayloads(): { CombatActorTypePayload }
	local payloads = {}
	for _, payload in pairs(self._actorTypes) do
		table.insert(payloads, payload)
	end
	table.sort(payloads, function(left: CombatActorTypePayload, right: CombatActorTypePayload): boolean
		return left.ActorType < right.ActorType
	end)
	return payloads
end

function CombatActorRegistryService:GetActorTypePayload(actorType: string): CombatActorTypePayload?
	return self._actorTypes[actorType]
end

function CombatActorRegistryService:GetRecord(runtimeId: number): CombatActorRecord?
	return self._recordsByRuntimeId[runtimeId]
end

function CombatActorRegistryService:GetRecordByHandle(actorHandle: string): CombatActorRecord?
	local runtimeId = self._runtimeIdsByHandle[actorHandle]
	if runtimeId == nil then
		return nil
	end
	return self._recordsByRuntimeId[runtimeId]
end

function CombatActorRegistryService:GetActionStateByHandle(actorHandle: string): CombatActionState?
	local runtimeId = self._runtimeIdsByHandle[actorHandle]
	if runtimeId == nil then
		return nil
	end

	return self:GetActionState(runtimeId)
end

function CombatActorRegistryService:QueryActiveRuntimeIds(actorType: string): { number }
	local runtimeIds = self._runtimeIdsByActorType[actorType]
	if runtimeIds == nil then
		return {}
	end

	local activeRuntimeIds = {}
	for _, runtimeId in ipairs(runtimeIds) do
		local record = self._recordsByRuntimeId[runtimeId]
		if record ~= nil and self:_IsRecordActive(record) then
			table.insert(activeRuntimeIds, runtimeId)
		end
	end
	return activeRuntimeIds
end

function CombatActorRegistryService:GetCompiledBehaviorTree(runtimeId: number): any?
	local record = self._recordsByRuntimeId[runtimeId]
	return if record ~= nil then record.BehaviorTree else nil
end

function CombatActorRegistryService:GetActionState(runtimeId: number): CombatActionState?
	local record = self._recordsByRuntimeId[runtimeId]
	return if record ~= nil then table.clone(record.ActionState) else nil
end

function CombatActorRegistryService:SetActionState(runtimeId: number, actionState: CombatActionState)
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

function CombatActorRegistryService:ClearActionState(runtimeId: number)
	local record = self._recordsByRuntimeId[runtimeId]
	if record == nil then
		return
	end
	record.ActionState = self:_BuildDefaultActionState()
	self:_NotifyActionStateChanged(record)
end

function CombatActorRegistryService:SetPendingAction(runtimeId: number, actionId: string, actionData: any?)
	local record = self._recordsByRuntimeId[runtimeId]
	if record == nil then
		return
	end

	if actionId == "AttackBase" and record.ActionState.PendingActionId ~= "AttackBase" then
		Result.MentionEvent("Combat:ActorRegistry", "Queued pending base attack action", {
			ActorType = record.ActorType,
			ActorHandle = record.ActorHandle,
			RuntimeId = runtimeId,
			CurrentActionId = record.ActionState.CurrentActionId,
		})
	end

	record.ActionState.PendingActionId = actionId
	record.ActionState.PendingActionData = actionData
end

function CombatActorRegistryService:UpdateLastTickTime(runtimeId: number, currentTime: number)
	local record = self._recordsByRuntimeId[runtimeId]
	if record == nil then
		return
	end
	record.LastTickTime = currentTime
end

function CombatActorRegistryService:ShouldEvaluate(runtimeId: number, currentTime: number): boolean
	local record = self._recordsByRuntimeId[runtimeId]
	if record == nil then
		return false
	end

	if record.ActionState.ActionState == "Committed" then
		return false
	end

	return currentTime - record.LastTickTime >= record.TickInterval
end

function CombatActorRegistryService:BuildFacts(runtimeId: number, currentTime: number): { [string]: any }
	local record = self._recordsByRuntimeId[runtimeId]
	if record == nil then
		return {}
	end

	local didBuild, facts = pcall(record.Adapter.BuildFacts, currentTime)
	if not didBuild or type(facts) ~= "table" then
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

function CombatActorRegistryService:BuildServices(runtimeId: number, currentTime: number): { [string]: any }
	local record = self._recordsByRuntimeId[runtimeId]
	if record == nil then
		return {}
	end

	local didBuild, services = pcall(record.Adapter.BuildServices, currentTime)
	if not didBuild or type(services) ~= "table" then
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

function CombatActorRegistryService:GetActorLabel(runtimeId: number): string?
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

function CombatActorRegistryService:CancelActor(runtimeId: number)
	local record = self._recordsByRuntimeId[runtimeId]
	if record == nil or record.Adapter.OnCancel == nil then
		return
	end

	local didCancel = pcall(record.Adapter.OnCancel)
	if not didCancel then
		Result.MentionError("Combat:ActorRegistry", "Actor cancel callback failed", {
			ActorType = record.ActorType,
			ActorHandle = record.ActorHandle,
			RuntimeId = runtimeId,
		}, "ActorCancelCallbackFailed")
	end
end

function CombatActorRegistryService:NotifyActionResult(runtimeId: number, actionResult: any)
	local record = self._recordsByRuntimeId[runtimeId]
	if record == nil or record.Adapter.OnActionResult == nil then
		return
	end

	local didNotify = pcall(record.Adapter.OnActionResult, actionResult)
	if not didNotify then
		Result.MentionError("Combat:ActorRegistry", "Actor action-result callback failed", {
			ActorType = record.ActorType,
			ActorHandle = record.ActorHandle,
			RuntimeId = runtimeId,
		}, "ActorActionResultCallbackFailed")
	end
end

function CombatActorRegistryService:ClearAll()
	table.clear(self._actorTypes)
	table.clear(self._recordsByRuntimeId)
	table.clear(self._runtimeIdsByHandle)
	table.clear(self._runtimeIdsByActorType)
	table.clear(self._pendingActorPayloadsByHandle)
	self._nextRuntimeId = 0
	self._runtimeStarted = false
end

local function _HasDeclaredSemanticRequirement(requirements: any): boolean
	if type(requirements) ~= "table" then
		return false
	end

	return requirements.FactsDependOnPolling == true or requirements.AttributesDependOnProjection == true
end

local function _ContainsPhase(registeredPhases: { string }, expectedPhase: string?): boolean
	if expectedPhase == nil then
		return #registeredPhases > 0
	end

	for _, registeredPhase in ipairs(registeredPhases) do
		if registeredPhase == expectedPhase then
			return true
		end
	end

	return false
end

function CombatActorRegistryService:_ValidateRuntimeBinding(payload: CombatActorTypePayload): Result.Err?
	local requirements = payload.SemanticRequirements
	if not _HasDeclaredSemanticRequirement(requirements) then
		return nil
	end

	local runtimeBinding = payload.RuntimeBinding
	if runtimeBinding == nil then
		return Err("MissingActorRuntimeBinding", Errors.MISSING_ACTOR_RUNTIME_BINDING, {
			ActorType = payload.ActorType,
		})
	end

	local runtimeOwner = payload.RuntimeOwner
	local getStatus = if type(runtimeOwner) == "table" then runtimeOwner.GetSchedulerBindingStatus else nil
	if type(getStatus) ~= "function" then
		return Err("InvalidActorRuntimeBindingOwner", Errors.INVALID_ACTOR_RUNTIME_BINDING_OWNER, {
			ActorType = payload.ActorType,
			ServiceField = runtimeBinding.ServiceField,
		})
	end

	local statusResult = getStatus(runtimeOwner, runtimeBinding.ServiceField)
	if type(statusResult) ~= "table" or statusResult.success ~= true then
		return Err("InvalidActorRuntimeBindingOwner", Errors.INVALID_ACTOR_RUNTIME_BINDING_OWNER, {
			ActorType = payload.ActorType,
			ServiceField = runtimeBinding.ServiceField,
			CauseType = if type(statusResult) == "table" then statusResult.type else "MissingResult",
			CauseMessage = if type(statusResult) == "table"
				then statusResult.message
				else "Runtime owner did not return a successful scheduler binding Result",
		})
	end

	local bindingStatus = statusResult.value
	if type(bindingStatus) ~= "table" or bindingStatus.TargetExists ~= true then
		return Err("InvalidActorRuntimeBindingOwner", Errors.INVALID_ACTOR_RUNTIME_BINDING_OWNER, {
			ActorType = payload.ActorType,
			ServiceField = runtimeBinding.ServiceField,
			CauseMessage = "Runtime owner did not expose the bound service field",
		})
	end

	if requirements.FactsDependOnPolling == true then
		local pollStatus = bindingStatus.Poll
		if type(pollStatus) ~= "table" or pollStatus.HasMethod ~= true then
			return Err("ActorPollingRequirementUnsatisfied", Errors.ACTOR_POLL_REQUIREMENT_UNSATISFIED, {
				ActorType = payload.ActorType,
				ServiceField = runtimeBinding.ServiceField,
				ExpectedMethod = "Poll",
				MissingRequirement = "FactsDependOnPolling",
			})
		end

		if type(pollStatus.RegisteredPhases) ~= "table" or not _ContainsPhase(pollStatus.RegisteredPhases, runtimeBinding.PollPhase) then
			return Err("ActorPollingRequirementUnsatisfied", Errors.ACTOR_POLL_REQUIREMENT_UNSATISFIED, {
				ActorType = payload.ActorType,
				ServiceField = runtimeBinding.ServiceField,
				ExpectedMethod = "Poll",
				ExpectedPhase = runtimeBinding.PollPhase,
				MissingRequirement = "FactsDependOnPolling",
			})
		end
	end

	if requirements.AttributesDependOnProjection == true then
		local syncStatus = bindingStatus.Sync
		if type(syncStatus) ~= "table" or syncStatus.HasMethod ~= true then
			return Err("ActorProjectionRequirementUnsatisfied", Errors.ACTOR_PROJECTION_REQUIREMENT_UNSATISFIED, {
				ActorType = payload.ActorType,
				ServiceField = runtimeBinding.ServiceField,
				ExpectedMethod = "SyncDirtyEntities",
				MissingRequirement = "AttributesDependOnProjection",
			})
		end

		if type(syncStatus.RegisteredPhases) ~= "table" or not _ContainsPhase(syncStatus.RegisteredPhases, runtimeBinding.SyncPhase) then
			return Err("ActorProjectionRequirementUnsatisfied", Errors.ACTOR_PROJECTION_REQUIREMENT_UNSATISFIED, {
				ActorType = payload.ActorType,
				ServiceField = runtimeBinding.ServiceField,
				ExpectedMethod = "SyncDirtyEntities",
				ExpectedPhase = runtimeBinding.SyncPhase,
				MissingRequirement = "AttributesDependOnProjection",
			})
		end
	end

	return nil
end

function CombatActorRegistryService:_ValidateActorTypePayload(payload: CombatActorTypePayload): Result.Err?
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

	local requirements = payload.SemanticRequirements
	if requirements ~= nil then
		if type(requirements) ~= "table" then
			return Err("InvalidActorTypePayload", Errors.INVALID_ACTOR_TYPE_PAYLOAD, {
				ActorType = payload.ActorType,
			})
		end

		if requirements.FactsDependOnPolling ~= nil and type(requirements.FactsDependOnPolling) ~= "boolean" then
			return Err("InvalidActorTypePayload", Errors.INVALID_ACTOR_TYPE_PAYLOAD, {
				ActorType = payload.ActorType,
			})
		end

		if requirements.AttributesDependOnProjection ~= nil and type(requirements.AttributesDependOnProjection) ~= "boolean" then
			return Err("InvalidActorTypePayload", Errors.INVALID_ACTOR_TYPE_PAYLOAD, {
				ActorType = payload.ActorType,
			})
		end
	end

	local runtimeBinding = payload.RuntimeBinding
	if runtimeBinding ~= nil then
		if type(runtimeBinding) ~= "table" then
			return Err("InvalidActorTypePayload", Errors.INVALID_ACTOR_TYPE_PAYLOAD, {
				ActorType = payload.ActorType,
			})
		end

		if type(runtimeBinding.ServiceField) ~= "string" or runtimeBinding.ServiceField == "" then
			return Err("InvalidActorTypePayload", Errors.INVALID_ACTOR_TYPE_PAYLOAD, {
				ActorType = payload.ActorType,
			})
		end

		if runtimeBinding.PollPhase ~= nil and (type(runtimeBinding.PollPhase) ~= "string" or runtimeBinding.PollPhase == "") then
			return Err("InvalidActorTypePayload", Errors.INVALID_ACTOR_TYPE_PAYLOAD, {
				ActorType = payload.ActorType,
			})
		end

		if runtimeBinding.SyncPhase ~= nil and (type(runtimeBinding.SyncPhase) ~= "string" or runtimeBinding.SyncPhase == "") then
			return Err("InvalidActorTypePayload", Errors.INVALID_ACTOR_TYPE_PAYLOAD, {
				ActorType = payload.ActorType,
			})
		end
	end

	local runtimeBindingError = self:_ValidateRuntimeBinding(payload)
	if runtimeBindingError ~= nil then
		return runtimeBindingError
	end

	return nil
end

function CombatActorRegistryService:_ValidateActorPayload(payload: CombatActorPayload): Result.Err?
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

function CombatActorRegistryService:_BuildDefaultActionState(): CombatActionState
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

function CombatActorRegistryService:_RemoveRuntimeId(runtimeId: number)
	local record = self._recordsByRuntimeId[runtimeId]
	if record == nil then
		return
	end

	self._recordsByRuntimeId[runtimeId] = nil
	self._runtimeIdsByHandle[record.ActorHandle] = nil
	self._pendingActorPayloadsByHandle[record.ActorHandle] = nil

	local runtimeIds = self._runtimeIdsByActorType[record.ActorType]
	if runtimeIds == nil then
		return
	end

	for index, storedRuntimeId in ipairs(runtimeIds) do
		if storedRuntimeId == runtimeId then
			table.remove(runtimeIds, index)
			return
		end
	end
end

function CombatActorRegistryService:_NotifyActionStateChanged(record: CombatActorRecord)
	if record.Adapter.OnActionStateChanged == nil then
		return
	end

	local didNotify = pcall(record.Adapter.OnActionStateChanged, table.clone(record.ActionState))
	if not didNotify then
		Result.MentionError("Combat:ActorRegistry", "Actor action-state callback failed", {
			ActorType = record.ActorType,
			ActorHandle = record.ActorHandle,
			RuntimeId = record.RuntimeId,
		}, "ActorActionStateCallbackFailed")
	end
end

return CombatActorRegistryService
