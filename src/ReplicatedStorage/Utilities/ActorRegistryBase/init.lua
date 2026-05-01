--!strict

--[=[
    @class ActorRegistryBase
    Shared actor registry base that owns actor-type registration, queued payloads,
    live runtime records, and lookup helpers for derived registries.
    @server
    @client
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Result = require(ReplicatedStorage.Utilities.Result)
local ActorTypeMetadataPolicy = require(script.Policies.ActorTypeMetadataPolicy)
local Errors = require(script.Errors)

local Err = Result.Err
local Ok = Result.Ok

local ActorRegistryBase = {}
ActorRegistryBase.__index = ActorRegistryBase

--[=[
    Creates a fresh registry with empty type, record, and pending-payload indexes.
    @within ActorRegistryBase
    @return ActorRegistryBase -- New registry instance
]=]
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

--[=[
    Registers one actor type after validating its payload and shared metadata.
    @within ActorRegistryBase
    @param payload any -- Actor type registration payload
    @return any -- Result object describing success or validation failure
]=]
function ActorRegistryBase:RegisterActorType(payload: any): any
	-- Validate the subclass-owned payload shape before touching any registry state.
	local validationError = self:_ValidateActorTypePayload(payload)
	if validationError ~= nil then
		return validationError
	end

	-- Validate shared runtime-binding metadata before the type becomes visible.
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

	-- Store the validated payload and initialize the runtime-id index for this type.
	self._actorTypes[actorType] = self:_BuildStoredActorTypePayload(payload)
	self._runtimeIdsByActorType[actorType] = {}

	return Ok(true)
end

--[=[
    Registers one actor instance and indexes its live runtime record.
    @within ActorRegistryBase
    @param payload any -- Actor payload to register
    @param buildContext any? -- Optional subclass-owned context passed to record creation
    @return any -- Result object describing success or validation failure
]=]
function ActorRegistryBase:RegisterActor(payload: any, buildContext: any?): any
	-- Validate the payload and reject handle collisions before allocating a runtime id.
	local validationError = self:_ValidateActorPayload(payload)
	if validationError ~= nil then
		return validationError
	end

	local mutationError = self:_ValidateActorMutation(payload)
	if mutationError ~= nil then
		return mutationError
	end

	-- Build the live record first so all indexes point at the same object.
	self._nextRuntimeId += 1
	local runtimeId = self._nextRuntimeId
	local record = self:_BuildRecordFromPayload(payload, runtimeId, buildContext)

	self._recordsByRuntimeId[runtimeId] = record
	self._runtimeIdsByHandle[payload.ActorHandle] = runtimeId
	table.insert(self._runtimeIdsByActorType[payload.ActorType], runtimeId)

	return Ok(payload.ActorHandle)
end

--[=[
    Queues one actor payload for later registration.
    @within ActorRegistryBase
    @param payload any -- Actor payload to queue
    @return any -- Result object describing success or validation failure
]=]
function ActorRegistryBase:QueueActor(payload: any): any
	-- Validate the payload and reject handle collisions before queueing it.
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

--[=[
    Returns queued actor payloads sorted by handle for deterministic processing.
    @within ActorRegistryBase
    @return { any } -- Pending payloads in handle order
]=]
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

--[=[
    Returns queued actor payloads and clears the pending queue.
    @within ActorRegistryBase
    @return { any } -- Pending payloads in handle order
]=]
function ActorRegistryBase:ConsumePendingActorPayloads(): { any }
	local payloads = self:GetPendingActorPayloads()
	table.clear(self._pendingActorPayloadsByHandle)
	return payloads
end

--[=[
    Removes one queued actor payload by handle without touching live records.
    @within ActorRegistryBase
    @param actorHandle string -- Actor handle to remove from the pending queue
]=]
function ActorRegistryBase:RemovePendingActorPayload(actorHandle: string)
	self._pendingActorPayloadsByHandle[actorHandle] = nil
end

--[=[
    Removes one live actor by handle and fires the removal callback when present.
    @within ActorRegistryBase
    @param actorHandle string -- Actor handle to unregister
    @return any -- Result object describing success or failure
]=]
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

	-- Notify the derived registry before the live record disappears from the indexes.
	local record = self._recordsByRuntimeId[runtimeId]
	if record ~= nil then
		self:_InvokeRemovedCallback(record)
	end

	self:_RemoveRuntimeId(runtimeId)
	return Ok(true)
end

--[=[
    Removes one live actor by handle without returning a Result.
    @within ActorRegistryBase
    @param actorHandle string -- Actor handle to discard
    @return boolean -- Whether a live actor was removed
]=]
function ActorRegistryBase:DiscardActor(actorHandle: string): boolean
	local runtimeId = self._runtimeIdsByHandle[actorHandle]
	if runtimeId == nil then
		return false
	end

	self:_RemoveRuntimeId(runtimeId)
	return true
end

--[=[
    Marks whether the registry runtime has started.
    @within ActorRegistryBase
    @param isStarted boolean -- Whether the runtime has started
]=]
function ActorRegistryBase:SetRuntimeStarted(isStarted: boolean)
	self._runtimeStarted = isStarted
end

--[=[
    Returns whether the registry runtime has started.
    @within ActorRegistryBase
    @return boolean -- Runtime-started flag
]=]
function ActorRegistryBase:IsRuntimeStarted(): boolean
	return self._runtimeStarted
end

--[=[
    Returns actor type payloads sorted by actor type for deterministic iteration.
    @within ActorRegistryBase
    @return { any } -- Actor type payloads in actor-type order
]=]
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

--[=[
    Returns the stored payload for one actor type, if any.
    @within ActorRegistryBase
    @param actorType string -- Actor type name to look up
    @return any? -- Stored actor type payload or nil
]=]
function ActorRegistryBase:GetActorTypePayload(actorType: string): any?
	return self._actorTypes[actorType]
end

--[=[
    Returns the live record for one runtime id, if any.
    @within ActorRegistryBase
    @param runtimeId number -- Runtime id to look up
    @return any? -- Live record or nil
]=]
function ActorRegistryBase:GetRecord(runtimeId: number): any?
	return self._recordsByRuntimeId[runtimeId]
end

--[=[
    Returns the live record for one actor handle, if any.
    @within ActorRegistryBase
    @param actorHandle string -- Actor handle to look up
    @return any? -- Live record or nil
]=]
function ActorRegistryBase:GetRecordByHandle(actorHandle: string): any?
	local runtimeId = self._runtimeIdsByHandle[actorHandle]
	if runtimeId == nil then
		return nil
	end

	return self._recordsByRuntimeId[runtimeId]
end

--[=[
    Returns active runtime ids for one actor type.
    @within ActorRegistryBase
    @param actorType string -- Actor type to query
    @return { number } -- Active runtime ids in registration order
]=]
function ActorRegistryBase:QueryActiveRuntimeIds(actorType: string): { number }
	local runtimeIds = self._runtimeIdsByActorType[actorType]
	if runtimeIds == nil then
		return {}
	end

	-- Filter the stored ids so callers only receive live records that still count as active.
	local activeRuntimeIds = {}
	for _, runtimeId in ipairs(runtimeIds) do
		local record = self._recordsByRuntimeId[runtimeId]
		if record ~= nil and self:_IsRecordActive(record) then
			table.insert(activeRuntimeIds, runtimeId)
		end
	end

	return activeRuntimeIds
end

--[=[
    Clears all registry state and resets runtime counters.
    @within ActorRegistryBase
]=]
function ActorRegistryBase:ClearAll()
	table.clear(self._actorTypes)
	table.clear(self._recordsByRuntimeId)
	table.clear(self._runtimeIdsByHandle)
	table.clear(self._runtimeIdsByActorType)
	table.clear(self._pendingActorPayloadsByHandle)
	self._nextRuntimeId = 0
	self._runtimeStarted = false
end

-- Remove one live record from every registry index so lookup tables stay in sync.
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

-- Reject actor payloads that would collide with an existing live or queued handle.
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

-- Validate shared actor-type metadata before the subclass stores its payload.
function ActorRegistryBase:_ValidateSharedActorTypeMetadata(payload: any): any
	local validationResult = ActorTypeMetadataPolicy.Check(payload)
	if validationResult.success then
		return nil
	end

	return validationResult
end

-- Subclass hook: validate the actor type registration payload shape.
function ActorRegistryBase:_ValidateActorTypePayload(_payload: any): any
	error("ActorRegistryBase must implement _ValidateActorTypePayload")
end

-- Subclass hook: validate the actor payload before registration or queuing.
function ActorRegistryBase:_ValidateActorPayload(_payload: any): any
	error("ActorRegistryBase must implement _ValidateActorPayload")
end

-- Subclass hook: build the stored actor-type payload from the validated input.
function ActorRegistryBase:_BuildStoredActorTypePayload(_payload: any): any
	error("ActorRegistryBase must implement _BuildStoredActorTypePayload")
end

-- Subclass hook: build the live record from the validated actor payload.
function ActorRegistryBase:_BuildRecordFromPayload(_payload: any, _runtimeId: number, _buildContext: any?): any
	error("ActorRegistryBase must implement _BuildRecordFromPayload")
end

-- Subclass hook: decide whether a live record should be considered active.
function ActorRegistryBase:_IsRecordActive(_record: any): boolean
	error("ActorRegistryBase must implement _IsRecordActive")
end

-- Subclass hook: fire derived cleanup when a live record is removed.
function ActorRegistryBase:_InvokeRemovedCallback(_record: any)
	return
end

return ActorRegistryBase
