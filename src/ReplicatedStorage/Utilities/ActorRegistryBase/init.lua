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
local SetupValidationPolicy = require(script.Policies.SetupValidationPolicy)
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
	self._activeRuntimeIdsByActorType = {}
	self._activeRuntimeIdMembershipByActorType = {}
	self._pendingActorPayloadsByHandle = {}
	self._runtimeQueue = {}
	self._runtimeQueueMembership = {}
	self._runtimeQueueCursor = 1
	self._selectedTickId = nil
	self._selectedGlobalBatch = {}
	self._selectedByActorType = {}
	self._selectedServicedMembership = {}
	self._selectedServicedCount = 0
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
	self._activeRuntimeIdsByActorType[actorType] = {}
	self._activeRuntimeIdMembershipByActorType[actorType] = {}

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
	self:_AppendRuntimeQueueId(runtimeId)
	self:_TryAddActiveRuntimeId(record)

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
    Returns how many actor payloads are waiting for runtime registration.
    @within ActorRegistryBase
    @return number -- Pending actor payload count
]=]
function ActorRegistryBase:GetPendingActorPayloadCount(): number
	local count = 0
	for _ in pairs(self._pendingActorPayloadsByHandle) do
		count += 1
	end

	return count
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
    Validates that the derived registry is fully configured for AI runtime ownership.
    @within ActorRegistryBase
    @return any -- Result object describing whether the registry setup is valid
]=]
function ActorRegistryBase:ValidateSetup(): any
	return SetupValidationPolicy.Check(self, ActorRegistryBase)
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
    Returns cached active runtime ids for one actor type, revalidating only the cached active set.
    @within ActorRegistryBase
    @param actorType string -- Actor type to query
    @return { number } -- Active runtime ids in registration order
]=]
function ActorRegistryBase:QueryCachedActiveRuntimeIds(actorType: string): { number }
	local activeRuntimeIds = self._activeRuntimeIdsByActorType[actorType]
	if activeRuntimeIds == nil then
		return {}
	end

	local index = 1
	while index <= #activeRuntimeIds do
		local runtimeId = activeRuntimeIds[index]
		local record = self._recordsByRuntimeId[runtimeId]
		if record ~= nil and self:_IsRecordActive(record) then
			index += 1
		else
			self:_RemoveActiveRuntimeId(actorType, runtimeId)
		end
	end

	return activeRuntimeIds
end

--[=[
    Returns the cached or newly resolved global FIFO selection for one scheduler tick.
    @within ActorRegistryBase
    @param batchSize number -- Maximum active runtime ids to select for the tick
    @param tickId number -- Outer scheduler frame id used to cache the selection
    @return { number } -- Selected runtime ids in FIFO order
]=]
function ActorRegistryBase:ResolveSelectedBatchForTick(batchSize: number, tickId: number): { number }
	if self._selectedTickId == tickId then
		return self._selectedGlobalBatch
	end

	self._selectedServicedMembership = {}
	self._selectedServicedCount = 0

	if batchSize <= 0 then
		self._selectedTickId = tickId
		self._selectedGlobalBatch = {}
		self._selectedByActorType = {}
		return self._selectedGlobalBatch
	end

	local queueLength = #self._runtimeQueue
	if queueLength == 0 then
		self._runtimeQueueCursor = 1
		self._selectedTickId = tickId
		self._selectedGlobalBatch = {}
		self._selectedByActorType = {}
		return self._selectedGlobalBatch
	end

	local cursor = self._runtimeQueueCursor
	if cursor < 1 or cursor > queueLength then
		cursor = 1
	end

	local selectedGlobalBatch = {}
	local selectedByActorType = {}
	local selectedMembership = {}
	local inspectedSlots = 0
	local currentIndex = cursor
	local lastVisitedIndex = nil

	while inspectedSlots < queueLength and #selectedGlobalBatch < batchSize do
		local runtimeId = self._runtimeQueue[currentIndex]
		inspectedSlots += 1
		lastVisitedIndex = currentIndex

		if runtimeId ~= nil and self._runtimeQueueMembership[runtimeId] == true then
			local record = self._recordsByRuntimeId[runtimeId]
			if record == nil then
				self._runtimeQueueMembership[runtimeId] = nil
			elseif selectedMembership[runtimeId] ~= true and self:_IsRecordActive(record) then
				selectedMembership[runtimeId] = true
				table.insert(selectedGlobalBatch, runtimeId)

				local actorType = record.ActorType
				local actorTypeBatch = selectedByActorType[actorType]
				if actorTypeBatch == nil then
					actorTypeBatch = {}
					selectedByActorType[actorType] = actorTypeBatch
				end

				table.insert(actorTypeBatch, runtimeId)
			end
		end

		currentIndex += 1
		if currentIndex > queueLength then
			currentIndex = 1
		end
	end

	self._selectedTickId = tickId
	self._selectedGlobalBatch = selectedGlobalBatch
	self._selectedByActorType = selectedByActorType

	return selectedGlobalBatch
end

--[=[
    Returns the actor-type-specific subset of the cached global FIFO selection for one scheduler tick.
    @within ActorRegistryBase
    @param actorType string -- Actor type to project from the cached global selection
    @param batchSize number -- Maximum active runtime ids to select for the tick
    @param tickId number -- Outer scheduler frame id used to cache the selection
    @return { number } -- Selected runtime ids for the requested actor type
]=]
function ActorRegistryBase:GetSelectedRuntimeIdsForActorType(
	actorType: string,
	batchSize: number,
	tickId: number
): { number }
	self:ResolveSelectedBatchForTick(batchSize, tickId)

	local selectedRuntimeIds = self._selectedByActorType[actorType]
	if selectedRuntimeIds == nil then
		return {}
	end

	return selectedRuntimeIds
end

--[=[
    Marks one runtime id as fully serviced for the selected scheduler tick and rotates it to the queue tail.
    @within ActorRegistryBase
    @param runtimeId number -- Runtime id that finished its frame work.
    @param tickId number -- Scheduler tick id that owns the cached selected batch.
    @return boolean -- Whether the runtime id was part of the selected batch and was marked serviced.
]=]
function ActorRegistryBase:MarkRuntimeIdServiced(runtimeId: number, tickId: number): boolean
	if self._selectedTickId ~= tickId then
		return false
	end

	if self._selectedServicedMembership[runtimeId] == true then
		return false
	end

	if table.find(self._selectedGlobalBatch, runtimeId) == nil then
		return false
	end

	self._selectedServicedMembership[runtimeId] = true
	self._selectedServicedCount += 1

	if self._runtimeQueueMembership[runtimeId] == true and self._recordsByRuntimeId[runtimeId] ~= nil then
		self:_MoveRuntimeIdToQueueTail(runtimeId)
	end

	return true
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
	table.clear(self._activeRuntimeIdsByActorType)
	table.clear(self._activeRuntimeIdMembershipByActorType)
	table.clear(self._pendingActorPayloadsByHandle)
	table.clear(self._runtimeQueue)
	table.clear(self._runtimeQueueMembership)
	table.clear(self._selectedGlobalBatch)
	table.clear(self._selectedByActorType)
	table.clear(self._selectedServicedMembership)
	self._runtimeQueueCursor = 1
	self._selectedTickId = nil
	self._selectedServicedCount = 0
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
	self:_RemoveActiveRuntimeId(record.ActorType, runtimeId)

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

function ActorRegistryBase:_AppendRuntimeQueueId(runtimeId: number)
	if self._runtimeQueueMembership[runtimeId] == true then
		return
	end

	self._runtimeQueueMembership[runtimeId] = true
	table.insert(self._runtimeQueue, runtimeId)
end

function ActorRegistryBase:_MoveRuntimeIdToQueueTail(runtimeId: number)
	local queueLength = #self._runtimeQueue
	if queueLength <= 1 then
		return
	end

	for index, queuedRuntimeId in ipairs(self._runtimeQueue) do
		if queuedRuntimeId == runtimeId then
			table.remove(self._runtimeQueue, index)
			table.insert(self._runtimeQueue, runtimeId)
			self._runtimeQueueCursor = 1
			return
		end
	end
end

function ActorRegistryBase:_TryAddActiveRuntimeId(record: any)
	local actorType = record.ActorType
	local activeRuntimeIds = self._activeRuntimeIdsByActorType[actorType]
	local membershipByRuntimeId = self._activeRuntimeIdMembershipByActorType[actorType]
	if activeRuntimeIds == nil or membershipByRuntimeId == nil then
		return
	end

	if membershipByRuntimeId[record.RuntimeId] == true then
		return
	end

	if not self:_IsRecordActive(record) then
		return
	end

	membershipByRuntimeId[record.RuntimeId] = true
	table.insert(activeRuntimeIds, record.RuntimeId)
end

function ActorRegistryBase:_RemoveActiveRuntimeId(actorType: string, runtimeId: number)
	local membershipByRuntimeId = self._activeRuntimeIdMembershipByActorType[actorType]
	if membershipByRuntimeId == nil or membershipByRuntimeId[runtimeId] ~= true then
		return
	end

	membershipByRuntimeId[runtimeId] = nil
	local activeRuntimeIds = self._activeRuntimeIdsByActorType[actorType]
	if activeRuntimeIds == nil then
		return
	end

	for index, activeRuntimeId in ipairs(activeRuntimeIds) do
		if activeRuntimeId == runtimeId then
			table.remove(activeRuntimeIds, index)
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
