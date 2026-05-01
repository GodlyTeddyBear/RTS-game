--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Result = require(ReplicatedStorage.Utilities.Result)
local ActorTypeMetadataPolicy = require(script.Policies.ActorTypeMetadataPolicy)
local Errors = require(script.Errors)

local Err = Result.Err
local Ok = Result.Ok

-- The shared base owns actor-registry bookkeeping plus utility-local metadata validation.
-- Derived registries provide payload-shape validation, record construction, and domain-specific record behavior.
-- Register and queue payloads are expected to expose `ActorType` and `ActorHandle`.
-- Live records are expected to expose `RuntimeId`, `ActorType`, `ActorHandle`, and `Adapter`.
-- `buildContext` is intentionally subclass-owned; the base does not define its shape.
local ActorRegistryBase = {}
ActorRegistryBase.__index = ActorRegistryBase

function ActorRegistryBase.new()
	local self = setmetatable({}, ActorRegistryBase)
	self._actorTypes = {}
	self._recordsByRuntimeId = {}
	self._runtimeIdsByHandle = {}
	self._runtimeIdsByActorType = {}
	self._pendingActorPayloadsByHandle = {}
	self._nextRuntimeId = 0
	self._runtimeStarted = false
	return self
end

function ActorRegistryBase:RegisterActorType(payload: any): any
	local validationError = self:_ValidateActorTypePayload(payload)
	if validationError ~= nil then
		return validationError
	end

	local metadataValidationError = self:_ValidateSharedActorTypeMetadata(payload)
	if metadataValidationError ~= nil then
		return metadataValidationError
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

	self._actorTypes[actorType] = self:_BuildStoredActorTypePayload(payload)
	self._runtimeIdsByActorType[actorType] = {}

	return Ok(true)
end

function ActorRegistryBase:RegisterActor(payload: any, buildContext: any?): any
	local validationError = self:_ValidateActorPayload(payload)
	if validationError ~= nil then
		return validationError
	end

	local mutationError = self:_ValidateActorMutation(payload)
	if mutationError ~= nil then
		return mutationError
	end

	self._nextRuntimeId += 1
	local runtimeId = self._nextRuntimeId
	local record = self:_BuildRecordFromPayload(payload, runtimeId, buildContext)

	self._recordsByRuntimeId[runtimeId] = record
	self._runtimeIdsByHandle[payload.ActorHandle] = runtimeId
	table.insert(self._runtimeIdsByActorType[payload.ActorType], runtimeId)

	return Ok(payload.ActorHandle)
end

function ActorRegistryBase:QueueActor(payload: any): any
	local validationError = self:_ValidateActorPayload(payload)
	if validationError ~= nil then
		return validationError
	end

	local mutationError = self:_ValidateActorMutation(payload)
	if mutationError ~= nil then
		return mutationError
	end

	self._pendingActorPayloadsByHandle[payload.ActorHandle] = payload
	return Ok(payload.ActorHandle)
end

function ActorRegistryBase:GetPendingActorPayloads(): { any }
	local payloads = {}
	for _, payload in pairs(self._pendingActorPayloadsByHandle) do
		table.insert(payloads, payload)
	end

	table.sort(payloads, function(left: any, right: any): boolean
		return left.ActorHandle < right.ActorHandle
	end)

	return payloads
end

function ActorRegistryBase:ConsumePendingActorPayloads(): { any }
	local payloads = self:GetPendingActorPayloads()
	table.clear(self._pendingActorPayloadsByHandle)
	return payloads
end

function ActorRegistryBase:RemovePendingActorPayload(actorHandle: string)
	self._pendingActorPayloadsByHandle[actorHandle] = nil
end

function ActorRegistryBase:UnregisterActor(actorHandle: string): any
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
	if record ~= nil then
		self:_InvokeRemovedCallback(record)
	end

	self:_RemoveRuntimeId(runtimeId)
	return Ok(true)
end

function ActorRegistryBase:DiscardActor(actorHandle: string): boolean
	local runtimeId = self._runtimeIdsByHandle[actorHandle]
	if runtimeId == nil then
		return false
	end

	self:_RemoveRuntimeId(runtimeId)
	return true
end

function ActorRegistryBase:SetRuntimeStarted(isStarted: boolean)
	self._runtimeStarted = isStarted
end

function ActorRegistryBase:IsRuntimeStarted(): boolean
	return self._runtimeStarted
end

function ActorRegistryBase:GetActorTypePayloads(): { any }
	local payloads = {}
	for _, payload in pairs(self._actorTypes) do
		table.insert(payloads, payload)
	end

	table.sort(payloads, function(left: any, right: any): boolean
		return left.ActorType < right.ActorType
	end)

	return payloads
end

function ActorRegistryBase:GetActorTypePayload(actorType: string): any?
	return self._actorTypes[actorType]
end

function ActorRegistryBase:GetRecord(runtimeId: number): any?
	return self._recordsByRuntimeId[runtimeId]
end

function ActorRegistryBase:GetRecordByHandle(actorHandle: string): any?
	local runtimeId = self._runtimeIdsByHandle[actorHandle]
	if runtimeId == nil then
		return nil
	end

	return self._recordsByRuntimeId[runtimeId]
end

function ActorRegistryBase:QueryActiveRuntimeIds(actorType: string): { number }
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

function ActorRegistryBase:ClearAll()
	table.clear(self._actorTypes)
	table.clear(self._recordsByRuntimeId)
	table.clear(self._runtimeIdsByHandle)
	table.clear(self._runtimeIdsByActorType)
	table.clear(self._pendingActorPayloadsByHandle)
	self._nextRuntimeId = 0
	self._runtimeStarted = false
end

function ActorRegistryBase:_RemoveRuntimeId(runtimeId: number)
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

function ActorRegistryBase:_ValidateActorMutation(payload: any): any
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

function ActorRegistryBase:_ValidateSharedActorTypeMetadata(payload: any): any
	local validationResult = ActorTypeMetadataPolicy.Check(payload)
	if validationResult.success then
		return nil
	end

	return validationResult
end

function ActorRegistryBase:_ValidateActorTypePayload(_payload: any): any
	error("ActorRegistryBase must implement _ValidateActorTypePayload")
end

function ActorRegistryBase:_ValidateActorPayload(_payload: any): any
	error("ActorRegistryBase must implement _ValidateActorPayload")
end

function ActorRegistryBase:_BuildStoredActorTypePayload(_payload: any): any
	error("ActorRegistryBase must implement _BuildStoredActorTypePayload")
end

function ActorRegistryBase:_BuildRecordFromPayload(_payload: any, _runtimeId: number, _buildContext: any?): any
	error("ActorRegistryBase must implement _BuildRecordFromPayload")
end

function ActorRegistryBase:_IsRecordActive(_record: any): boolean
	error("ActorRegistryBase must implement _IsRecordActive")
end

function ActorRegistryBase:_InvokeRemovedCallback(_record: any)
	return
end

return ActorRegistryBase
