--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SchedulePlus = require(ReplicatedStorage.Utilities.SchedulePlus)

local function _ResolveQueueState(self: any, queueKey: string): any
	return self._queueState[queueKey]
end

local function _ResolveDroppedStatus(self: any, entity: number, services: any, config: any, dropReason: string?): string
	local droppedStatus = if type(config) == "table" then config.DroppedStatus else nil
	if type(droppedStatus) == "string" then
		return droppedStatus
	end

	if type(droppedStatus) == "function" then
		local resolvedStatus = droppedStatus(entity, services, dropReason)
		assert(type(resolvedStatus) == "string", "BaseExecutor:RunQueued DroppedStatus callback must return a string")
		return resolvedStatus
	end

	error("BaseExecutor:RunQueued requires config.DroppedStatus to resolve dropped turns", 2)
end

local function _ResolveQueueTickId(services: any): number
	assert(type(services) == "table", "BaseExecutor queue service helpers require a services table")

	local tickId = services.TickId
	if type(tickId) == "number" then
		return tickId
	end

	local frameId = services.FrameId
	if type(frameId) == "number" then
		return frameId
	end

	error("BaseExecutor queue service helpers require services.TickId or services.FrameId", 2)
end

local function _AssertQueueConfigMatches(queueKey: string, queueState: any, config: any)
	assert(
		queueState.CapacityPerTick == config.CapacityPerTick,
		string.format(
			"BaseExecutor queue '%s' already exists with CapacityPerTick=%d and cannot be reconfigured to %d",
			queueKey,
			queueState.CapacityPerTick,
			config.CapacityPerTick
		)
	)
end

local function _CreatePendingEntitiesSnapshot(queueState: any): { number }
	local pendingEntities = table.create(#queueState.PendingBatch)
	for _, item in ipairs(queueState.PendingBatch) do
		table.insert(pendingEntities, item.Entity)
	end

	return pendingEntities
end

local function _ResetQueueTickState(queueState: any, tickId: number)
	if queueState.LastServicedTickId == tickId then
		return
	end

	queueState.LastServicedTickId = tickId
	queueState.GrantedCountThisTick = 0
	queueState.HasNewArrivalsSinceLastService = true
	queueState.GrantedItemsByEntity = {}
	queueState.DroppedReasonsByEntity = {}
end

local function _DropQueueEntity(queueState: any, entity: number, reason: string)
	queueState.Membership[entity] = nil
	queueState.MetadataByEntity[entity] = nil
	queueState.GrantedItemsByEntity[entity] = nil
	queueState.DroppedReasonsByEntity[entity] = reason
end

local function _CompactPendingBatch(self: any, queueState: any): { any }
	local remainingBatch = table.create(#queueState.PendingBatch)
	for _, item in ipairs(queueState.PendingBatch) do
		local entity = item.Entity
		if queueState.Membership[entity] ~= true then
			continue
		end

		if not self:IsGenerationCurrent(entity, item.Generation) then
			_DropQueueEntity(queueState, entity, "StaleGeneration")
			continue
		end

		item.Metadata = queueState.MetadataByEntity[entity]
		table.insert(remainingBatch, item)
	end

	return remainingBatch
end

local function _ServiceQueue(self: any, queueKey: string, services: any, config: any)
	local queueState = _ResolveQueueState(self, queueKey)
	if queueState == nil then
		return
	end

	local tickId = _ResolveQueueTickId(services)
	_ResetQueueTickState(queueState, tickId)

	if queueState.GrantedCountThisTick >= queueState.CapacityPerTick then
		return
	end

	if not queueState.HasNewArrivalsSinceLastService and #queueState.PendingBatch == 0 then
		return
	end

	queueState.Queue:Flush()
	queueState.PendingBatch = _CompactPendingBatch(self, queueState)
	queueState.HasNewArrivalsSinceLastService = false

	local canRun = if type(config) == "table" then config.CanRun else nil
	local remainingBatch = table.create(#queueState.PendingBatch)

	for _, item in ipairs(queueState.PendingBatch) do
		local entity = item.Entity
		local currentMetadata = queueState.MetadataByEntity[entity]

		if type(canRun) == "function" and not canRun(entity, services, currentMetadata) then
			_DropQueueEntity(queueState, entity, "CanRunFailed")
			continue
		end

		if queueState.GrantedCountThisTick < queueState.CapacityPerTick then
			queueState.Membership[entity] = nil
			queueState.MetadataByEntity[entity] = nil
			queueState.GrantedItemsByEntity[entity] = {
				Entity = item.Entity,
				Metadata = currentMetadata,
				Generation = item.Generation,
				EnqueuedAt = item.EnqueuedAt,
			}
			queueState.GrantedCountThisTick += 1
			continue
		end

		item.Metadata = currentMetadata
		table.insert(remainingBatch, item)
	end

	queueState.PendingBatch = remainingBatch
end

return function(BaseExecutor)
	function BaseExecutor:BeginQueue(queueKey: string, config: any): any
		assert(type(queueKey) == "string" and queueKey ~= "", "BaseExecutor:BeginQueue requires a non-empty queueKey")
		assert(type(config) == "table", "BaseExecutor:BeginQueue requires a config table")
		assert(
			type(config.CapacityPerTick) == "number" and config.CapacityPerTick > 0,
			"BaseExecutor:BeginQueue requires CapacityPerTick > 0"
		)

		local existingQueueState = self._queueState[queueKey]
		if existingQueueState ~= nil then
			_AssertQueueConfigMatches(queueKey, existingQueueState, config)
			return existingQueueState
		end

		local queueState = nil
		queueState = {
			Queue = SchedulePlus.Queue({
				FlushMode = "Manual",
				OnFlush = function(batch)
					for _, item in ipairs(batch) do
						table.insert(queueState.PendingBatch, item)
					end
				end,
			}),
			CapacityPerTick = config.CapacityPerTick,
			Membership = {},
			MetadataByEntity = {},
			PendingBatch = {},
			GrantedItemsByEntity = {},
			DroppedReasonsByEntity = {},
			LastServicedTickId = nil,
			GrantedCountThisTick = 0,
			HasNewArrivalsSinceLastService = false,
		}

		self._queueState[queueKey] = queueState
		return queueState
	end

	function BaseExecutor:HasQueue(queueKey: string): boolean
		return _ResolveQueueState(self, queueKey) ~= nil
	end

	function BaseExecutor:ClearQueue(queueKey: string)
		local queueState = _ResolveQueueState(self, queueKey)
		if queueState == nil then
			return
		end

		queueState.Queue:Clear()
		queueState.Queue:Destroy()
		table.clear(queueState.Membership)
		table.clear(queueState.MetadataByEntity)
		table.clear(queueState.PendingBatch)
		table.clear(queueState.GrantedItemsByEntity)
		table.clear(queueState.DroppedReasonsByEntity)
		self._queueState[queueKey] = nil
	end

	function BaseExecutor:ClearAllQueues()
		local queueKeys = {}
		for queueKey in pairs(self._queueState) do
			table.insert(queueKeys, queueKey)
		end

		for _, queueKey in ipairs(queueKeys) do
			self:ClearQueue(queueKey)
		end
	end

	function BaseExecutor:IsQueued(entity: number, queueKey: string): boolean
		local queueState = _ResolveQueueState(self, queueKey)
		if queueState == nil then
			return false
		end

		return queueState.Membership[entity] == true
	end

	function BaseExecutor:Enqueue(entity: number, queueKey: string, metadata: any?): boolean
		local queueState = _ResolveQueueState(self, queueKey)
		assert(queueState ~= nil, string.format("BaseExecutor queue '%s' has not been initialized", queueKey))

		if queueState.Membership[entity] == true then
			if metadata ~= nil then
				queueState.MetadataByEntity[entity] = metadata
			end
			return false
		end

		local queueItem = {
			Entity = entity,
			Metadata = metadata,
			Generation = self:CaptureEntityGeneration(entity),
			EnqueuedAt = if type(metadata) == "table" and type(metadata.EnqueuedAt) == "number" then metadata.EnqueuedAt else nil,
		}

		queueState.Membership[entity] = true
		queueState.MetadataByEntity[entity] = metadata
		queueState.DroppedReasonsByEntity[entity] = nil
		queueState.Queue:Add(queueItem)
		queueState.HasNewArrivalsSinceLastService = true
		return true
	end

	function BaseExecutor:Dequeue(entity: number, queueKey: string)
		local queueState = _ResolveQueueState(self, queueKey)
		if queueState == nil then
			return
		end

		queueState.Membership[entity] = nil
		queueState.MetadataByEntity[entity] = nil
		queueState.GrantedItemsByEntity[entity] = nil
		queueState.DroppedReasonsByEntity[entity] = nil
	end

	function BaseExecutor:RemoveEntityFromQueues(entity: number)
		for _, queueState in pairs(self._queueState) do
			queueState.Membership[entity] = nil
			queueState.MetadataByEntity[entity] = nil
			queueState.GrantedItemsByEntity[entity] = nil
			queueState.DroppedReasonsByEntity[entity] = nil
		end
	end

	function BaseExecutor:HasQueuedWork(queueKey: string): boolean
		local queueState = _ResolveQueueState(self, queueKey)
		if queueState == nil then
			return false
		end

		return (queueState.Queue:GetSize() > 0) or (#queueState.PendingBatch > 0)
	end

	function BaseExecutor:GetQueueSize(queueKey: string): number
		local queueState = _ResolveQueueState(self, queueKey)
		if queueState == nil then
			return 0
		end

		local size = 0
		for entity in pairs(queueState.Membership) do
			if queueState.Membership[entity] == true then
				size += 1
			end
		end

		return size
	end

	function BaseExecutor:GetQueueSnapshot(queueKey: string): any
		local queueState = _ResolveQueueState(self, queueKey)
		if queueState == nil then
			return nil
		end

		return table.freeze({
			QueueKey = queueKey,
			CapacityPerTick = queueState.CapacityPerTick,
			QueuedCount = self:GetQueueSize(queueKey),
			FlushedPendingEntities = table.freeze(_CreatePendingEntitiesSnapshot(queueState)),
			BufferedQueuedCount = queueState.Queue:GetSize(),
			GrantedCountThisTick = queueState.GrantedCountThisTick,
			LastServicedTickId = queueState.LastServicedTickId,
		})
	end

	function BaseExecutor:RequestQueueTurn(entity: number, queueKey: string, services: any, config: any): string
		assert(type(config) == "table", "BaseExecutor:RequestQueueTurn requires a config table")

		local queueState = self:BeginQueue(queueKey, config)
		_ResetQueueTickState(queueState, _ResolveQueueTickId(services))

		local metadata = config.Metadata
		if queueState.Membership[entity] ~= true then
			self:Enqueue(entity, queueKey, metadata)
		elseif metadata ~= nil then
			queueState.MetadataByEntity[entity] = metadata
		end

		_ServiceQueue(self, queueKey, services, config)

		if queueState.GrantedItemsByEntity[entity] ~= nil then
			return "Granted"
		end

		if queueState.DroppedReasonsByEntity[entity] ~= nil then
			return "Dropped"
		end

		if queueState.Membership[entity] == true then
			return "Queued"
		end

		return "Dropped"
	end

	function BaseExecutor:RunQueued(entity: number, queueKey: string, services: any, config: any): string
		assert(type(config) == "table", "BaseExecutor:RunQueued requires a config table")
		assert(
			type(config.DroppedStatus) == "string" or type(config.DroppedStatus) == "function",
			"BaseExecutor:RunQueued requires config.DroppedStatus to resolve dropped turns"
		)
		local turnResult = self:RequestQueueTurn(entity, queueKey, services, config)
		local queueState = _ResolveQueueState(self, queueKey)
		if queueState == nil then
			return self:Fail(entity, "MissingQueue")
		end

		if turnResult == "Queued" then
			if type(config.OnQueued) == "function" then
				config.OnQueued(entity, services)
			end
			return self:Running()
		end

		if turnResult == "Dropped" then
			local dropReason = queueState.DroppedReasonsByEntity[entity]
			queueState.DroppedReasonsByEntity[entity] = nil
			if type(config.OnDropped) == "function" then
				config.OnDropped(entity, services, dropReason)
			end
			return _ResolveDroppedStatus(self, entity, services, config, dropReason)
		end

		local grantedItem = queueState.GrantedItemsByEntity[entity]
		queueState.GrantedItemsByEntity[entity] = nil
		if grantedItem == nil then
			return self:Running()
		end

		if type(config.OnGranted) == "function" then
			config.OnGranted(entity, services)
		end

		if type(config.Run) ~= "function" then
			return self:Running()
		end

		local status = config.Run(entity, services, grantedItem.Metadata)
		if type(status) == "string" then
			return status
		end

		return self:Running()
	end
end
