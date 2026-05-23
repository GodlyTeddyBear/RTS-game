--!strict

local CollectionService = game:GetService("CollectionService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local GoodSignal = require(ReplicatedStorage.Packages.Goodsignal)
local Janitor = require(ReplicatedStorage.Packages.Janitor)
local RenderCharacterExclusion = require(ReplicatedStorage.Contexts.Render.RenderCharacterExclusion)
local RenderConfig = require(ReplicatedStorage.Contexts.Render.Config.RenderConfig)
local RenderPropertyRegistry = require(ReplicatedStorage.Contexts.Render.RenderPropertyRegistry)
local RenderTransportSchema = require(ReplicatedStorage.Contexts.Render.RenderTransportSchema)
local RenderTypes = require(ReplicatedStorage.Contexts.Render.Types.RenderTypes)

type TRenderId = RenderTypes.TRenderId
type TRenderRegistryServerSoA = RenderTypes.TRenderRegistryServerSoA
type TRenderRegistryBootstrapChunk = RenderTypes.TRenderRegistryBootstrapChunk
type TRenderRegistryDelta = RenderTypes.TRenderRegistryDelta
type TRenderPropertyDescriptor = RenderPropertyRegistry.TRenderPropertyDescriptor

type TBootstrappingQueue = {
	AddedIdsById: { [TRenderId]: true },
	AddedPropertyValuesByKey: { [string]: { [TRenderId]: any } },
	RemovedIdsByPriority: { [number]: { [TRenderId]: true } },
}

type TStagedDeltaBucket = {
	AddedIdsById: { [TRenderId]: true },
	RemovedIdsById: { [TRenderId]: true },
}

local PROPERTY_DESCRIPTORS = RenderPropertyRegistry.GetDescriptors()
local ROOT_PRIORITY_BY_CONTAINER = RenderConfig.RootPriorityByContainer
local function _BuildTrackedRoots(): { Instance }
	local roots = {}
	for root in ROOT_PRIORITY_BY_CONTAINER do
		table.insert(roots, root)
	end
	table.sort(roots, function(left, right)
		local leftPriority = ROOT_PRIORITY_BY_CONTAINER[left] or 0
		local rightPriority = ROOT_PRIORITY_BY_CONTAINER[right] or 0
		if leftPriority == rightPriority then
			return left.Name < right.Name
		end

		return leftPriority > rightPriority
	end)
	return roots
end

local TRACKED_ROOTS = _BuildTrackedRoots()

local function _BuildClientVisibleRoots(): { Instance }
	local roots = {}
	for _, root in ipairs(TRACKED_ROOTS) do
		if root == Workspace or root == ReplicatedStorage then
			table.insert(roots, root)
		end
	end
	return roots
end

local CLIENT_VISIBLE_ROOTS = _BuildClientVisibleRoots()

local RenderRegistryService = {}
RenderRegistryService.__index = RenderRegistryService

local function _CreateServerSoA(): TRenderRegistryServerSoA
	local soa = {
		Count = 0,
		IndexById = {},
		IdsByIndex = {},
		InstancesByIndex = {},
	} :: any
	local soaAny = soa :: any

	for _, descriptor: TRenderPropertyDescriptor in ipairs(PROPERTY_DESCRIPTORS) do
		soaAny[descriptor.RuntimeColumn] = {}
	end

	return soa :: TRenderRegistryServerSoA
end

local function _CreatePropertyValueMapsByKey(): { [string]: { [TRenderId]: any } }
	local propertyValueMapsByKey = {}
	for _, descriptor: TRenderPropertyDescriptor in ipairs(PROPERTY_DESCRIPTORS) do
		propertyValueMapsByKey[descriptor.Key] = {}
	end

	return propertyValueMapsByKey
end

local function _CreateRemovedIdsByPriority(): { [number]: { [TRenderId]: true } }
	local removedIdsByPriority = {}
	for _, priority in ROOT_PRIORITY_BY_CONTAINER do
		removedIdsByPriority[priority] = {}
	end

	return removedIdsByPriority
end

local function _CreateStagedDeltaBuckets(): { [number]: TStagedDeltaBucket }
	local buckets = {}
	for _, priority in ROOT_PRIORITY_BY_CONTAINER do
		if buckets[priority] == nil then
			buckets[priority] = {
				AddedIdsById = {},
				RemovedIdsById = {},
			}
		end
	end

	return buckets
end

local function _BuildPriorityOrder(): { number }
	local priorities = {}
	local seen = {}
	for _, priority in ROOT_PRIORITY_BY_CONTAINER do
		if seen[priority] ~= true then
			seen[priority] = true
			table.insert(priorities, priority)
		end
	end
	table.sort(priorities, function(a, b)
		return a > b
	end)
	return priorities
end

local PRIORITY_ORDER = _BuildPriorityOrder()

function RenderRegistryService.new()
	local self = setmetatable({}, RenderRegistryService)
	self._janitor = Janitor.new()
	self.EntryChanged = GoodSignal.new()
	self.EntryRemoved = GoodSignal.new()
	self._clientSignals = nil
	self._soa = _CreateServerSoA()
	self._idByInstance = {} :: { [Instance]: TRenderId }
	self._clientVisibleById = {} :: { [TRenderId]: boolean }
	self._clientPublishedById = {} :: { [TRenderId]: boolean }
	self._pendingClientPublishById = {} :: { [TRenderId]: boolean }
	self._priorityById = {} :: { [TRenderId]: number }
	self._lastRemovedPriorityById = {} :: { [TRenderId]: number }
	self._hydratedPlayers = {} :: { [Player]: true }
	self._bootstrappingPlayers = {} :: { [Player]: TBootstrappingQueue }
	self._stagedDeltasByPriority = _CreateStagedDeltaBuckets()
	self._lastDeltaFlushAt = os.clock()
	return self
end

function RenderRegistryService:Init(registry: any, _name: string)
	self._clientSignals = registry:Get("ClientSignals")
	assert(self._clientSignals ~= nil, "RenderRegistryService: missing ClientSignals")
end

function RenderRegistryService:Start()
	self:_TrackPlayerLifecycle()
	self:_StartDeltaFlusher()
	self:_ScanTrackedRoots()
	self:_TrackTrackedRoots()
end

function RenderRegistryService:Destroy()
	if self.EntryChanged ~= nil then
		self.EntryChanged:DisconnectAll()
	end
	if self.EntryRemoved ~= nil then
		self.EntryRemoved:DisconnectAll()
	end

	self._janitor:Destroy()
	table.clear(self._soa.IndexById)
	table.clear(self._soa.IdsByIndex)
	table.clear(self._soa.InstancesByIndex)
	for _, descriptor: TRenderPropertyDescriptor in ipairs(PROPERTY_DESCRIPTORS) do
		table.clear((self._soa :: any)[descriptor.RuntimeColumn])
	end
	self._soa.Count = 0
	table.clear(self._idByInstance)
	table.clear(self._clientVisibleById)
	table.clear(self._clientPublishedById)
	table.clear(self._pendingClientPublishById)
	table.clear(self._priorityById)
	table.clear(self._lastRemovedPriorityById)
	table.clear(self._hydratedPlayers)
	table.clear(self._bootstrappingPlayers)
	for _, bucket in self._stagedDeltasByPriority do
		table.clear(bucket.AddedIdsById)
		table.clear(bucket.RemovedIdsById)
	end
end

function RenderRegistryService:GetRegistrySoA(): TRenderRegistryServerSoA
	return self._soa
end

function RenderRegistryService:GetIndexById(id: TRenderId): number?
	return self._soa.IndexById[id]
end

function RenderRegistryService:GetPriorityById(id: TRenderId): number
	return self._priorityById[id] or 0
end

function RenderRegistryService:NotifyServerRendered(id: TRenderId)
	if self._soa.IndexById[id] == nil then
		return
	end

	if self._clientVisibleById[id] ~= true or self._pendingClientPublishById[id] ~= true then
		return
	end

	self._pendingClientPublishById[id] = nil
	self._clientPublishedById[id] = true
	self:_StageAddedOrUpdatedIds({ id }, self._priorityById[id] or 0)
end

function RenderRegistryService:GetInstanceById(id: TRenderId): Instance?
	local index = self._soa.IndexById[id]
	if index == nil then
		return nil
	end

	return self._soa.InstancesByIndex[index]
end

function RenderRegistryService:GetCastShadowById(id: TRenderId): boolean?
	return self:GetPropertyValueById("CastShadow", id)
end

function RenderRegistryService:GetPropertyValueById(propertyKey: string, id: TRenderId): any?
	local descriptor = RenderPropertyRegistry.GetDescriptorByKey(propertyKey)
	if descriptor == nil then
		return nil
	end

	local index = self._soa.IndexById[id]
	if index == nil then
		return nil
	end

	return ((self._soa :: any)[descriptor.RuntimeColumn] :: { [number]: any })[index]
end

function RenderRegistryService:ObserveEntryChanged(callback: (id: TRenderId) -> ())
	return self.EntryChanged:Connect(callback)
end

function RenderRegistryService:ObserveEntryRemoved(callback: (id: TRenderId) -> ())
	return self.EntryRemoved:Connect(callback)
end

function RenderRegistryService:HydratePlayer(player: Player): boolean
	if not self:_IsPlayerValid(player) then
		return false
	end

	local queue = self:_CreateBootstrappingQueue()
	self._hydratedPlayers[player] = nil
	self._bootstrappingPlayers[player] = queue

	local visibleIds = self:_BuildSortedClientVisibleIds()
	local chunkSize = RenderConfig.RegistryBootstrapChunkSize
	local chunkCount = math.max(1, math.ceil(#visibleIds / chunkSize))
	local encodedChunks = table.create(chunkCount)

	for chunkIndex = 1, chunkCount do
		local startIndex = ((chunkIndex - 1) * chunkSize) + 1
		local endIndex = math.min(startIndex + chunkSize - 1, #visibleIds)
		local payload = self:_BuildBootstrapChunk(visibleIds, chunkIndex, chunkCount, startIndex, endIndex)
		local encodedPayload, serializeError = RenderTransportSchema.SerializeBootstrapChunk(payload)
		if encodedPayload == nil then
			warn(`RenderRegistryService: failed to serialize bootstrap chunk {chunkIndex}/{chunkCount}: {serializeError}`)
			self._bootstrappingPlayers[player] = nil
			return false
		end

		encodedChunks[chunkIndex] = encodedPayload
	end

	for chunkIndex = 1, chunkCount do
		self._clientSignals.RenderRegistryBootstrapChunk:Fire(player, encodedChunks[chunkIndex])
	end

	self._bootstrappingPlayers[player] = nil
	self._hydratedPlayers[player] = true
	self:_FlushQueuedDelta(player, queue)

	return true
end

function RenderRegistryService:_TrackPlayerLifecycle()
	self._janitor:Add(Players.PlayerRemoving:Connect(function(player: Player)
		self._hydratedPlayers[player] = nil
		self._bootstrappingPlayers[player] = nil
	end), "Disconnect")
end

function RenderRegistryService:_StartDeltaFlusher()
	self._janitor:Add(RunService.Heartbeat:Connect(function()
		local now = os.clock()
		if now - self._lastDeltaFlushAt < RenderConfig.ServerProfile.DeltaFlushIntervalSeconds then
			return
		end

		self._lastDeltaFlushAt = now
		self:_FlushStagedDeltas()
	end), "Disconnect")
end

function RenderRegistryService:_ScanTrackedRoots()
	for _, root in ipairs(TRACKED_ROOTS) do
		for _, descendant in root:GetDescendants() do
			self:_EnsureTrackedInstance(descendant)
		end
	end
end

function RenderRegistryService:_TrackTrackedRoots()
	for _, root in ipairs(TRACKED_ROOTS) do
		self._janitor:Add(root.DescendantAdded:Connect(function(instance: Instance)
			self:_EnsureTrackedInstance(instance)
		end), "Disconnect")

		self._janitor:Add(root.DescendantRemoving:Connect(function(instance: Instance)
			self:_QueuePotentialRemoval(instance)
		end), "Disconnect")
	end
end

function RenderRegistryService:_EnsureTrackedInstance(instance: Instance): TRenderId?
	if RenderCharacterExclusion.IsExcludedInstance(instance) then
		local existingId = self._idByInstance[instance]
		if existingId ~= nil then
			local wasClientVisible = self._clientVisibleById[existingId] == true
			local previousPriority = self._priorityById[existingId] or 0
			self:_RemoveById(existingId)

			if CollectionService:HasTag(instance, self:_BuildTag(existingId)) then
				CollectionService:RemoveTag(instance, self:_BuildTag(existingId))
			end

			self.EntryRemoved:Fire(existingId)
			if wasClientVisible then
				self:_StageRemovedIds({ existingId }, previousPriority)
			end
		end

		return nil
	end

	if not self:_IsTrackedInstance(instance) then
		return nil
	end

	if not self:_IsDescendantOfTrackedRoot(instance) then
		return nil
	end

	local existingId = self._idByInstance[instance]
	if existingId ~= nil then
		self:_HandleVisibilityChange(existingId, instance)
		return existingId
	end

	local id = self:_CreateRuntimeId()
	local index = self._soa.Count + 1
	local isClientVisible = self:_IsClientVisible(instance)
	local priority = self:_GetPriorityForInstance(instance)

	self._soa.Count = index
	self._soa.IndexById[id] = index
	self._soa.IdsByIndex[index] = id
	self._soa.InstancesByIndex[index] = instance
	self:_SnapshotPropertyValues(instance, index)
	self._idByInstance[instance] = id
	self._clientVisibleById[id] = isClientVisible
	self._clientPublishedById[id] = false
	self._pendingClientPublishById[id] = isClientVisible
	self._priorityById[id] = priority

	CollectionService:AddTag(instance, self:_BuildTag(id))
	self.EntryChanged:Fire(id)

	return id
end

function RenderRegistryService:_HandleVisibilityChange(id: TRenderId, instance: Instance)
	local wasClientVisible = self._clientVisibleById[id] == true
	local wasPublished = self._clientPublishedById[id] == true
	local wasPriority = self._priorityById[id] or 0
	local isClientVisible = self:_IsClientVisible(instance)
	local priority = self:_GetPriorityForInstance(instance)
	self._clientVisibleById[id] = isClientVisible
	self._priorityById[id] = priority

	if wasClientVisible == isClientVisible and wasPriority == priority then
		return
	end

	self.EntryChanged:Fire(id)
	if isClientVisible then
		self._clientPublishedById[id] = false
		self._pendingClientPublishById[id] = true
	else
		self._pendingClientPublishById[id] = nil
		self._clientPublishedById[id] = nil
		if wasPublished then
			self:_StageRemovedIds({ id }, wasPriority)
		end
	end
end

function RenderRegistryService:_QueuePotentialRemoval(instance: Instance)
	if self._idByInstance[instance] == nil then
		return
	end

	task.defer(function()
		self:_FinalizeRemoval(instance)
	end)
end

function RenderRegistryService:_FinalizeRemoval(instance: Instance)
	local id = self._idByInstance[instance]
	if id == nil then
		return
	end

	if self:_IsDescendantOfTrackedRoot(instance) then
		self:_EnsureTrackedInstance(instance)
		return
	end

	local wasClientVisible = self._clientVisibleById[id] == true
	local previousPriority = self._priorityById[id] or 0
	self:_RemoveById(id)

	if CollectionService:HasTag(instance, self:_BuildTag(id)) then
		CollectionService:RemoveTag(instance, self:_BuildTag(id))
	end

	self.EntryRemoved:Fire(id)
	if wasClientVisible then
		self:_StageRemovedIds({ id }, previousPriority)
	end
end

function RenderRegistryService:_RemoveById(id: TRenderId)
	local removeIndex = self._soa.IndexById[id]
	if removeIndex == nil then
		return
	end

	local lastIndex = self._soa.Count
	local removedInstance = self._soa.InstancesByIndex[removeIndex]
	local movedId = self._soa.IdsByIndex[lastIndex]

	if removeIndex ~= lastIndex then
		self._soa.IdsByIndex[removeIndex] = movedId
		self._soa.InstancesByIndex[removeIndex] = self._soa.InstancesByIndex[lastIndex]
		for _, descriptor: TRenderPropertyDescriptor in ipairs(PROPERTY_DESCRIPTORS) do
			local runtimeColumn = (self._soa :: any)[descriptor.RuntimeColumn] :: { [number]: any }
			runtimeColumn[removeIndex] = runtimeColumn[lastIndex]
		end
		self._soa.IndexById[movedId] = removeIndex
	end

	self._soa.IdsByIndex[lastIndex] = nil
	self._soa.InstancesByIndex[lastIndex] = nil
	for _, descriptor: TRenderPropertyDescriptor in ipairs(PROPERTY_DESCRIPTORS) do
		local runtimeColumn = (self._soa :: any)[descriptor.RuntimeColumn] :: { [number]: any }
		runtimeColumn[lastIndex] = nil
	end
	self._soa.IndexById[id] = nil
	self._soa.Count -= 1

	if removedInstance ~= nil then
		self._idByInstance[removedInstance] = nil
	end
	self._clientVisibleById[id] = nil
	self._clientPublishedById[id] = nil
	self._pendingClientPublishById[id] = nil
	self._priorityById[id] = nil
end

function RenderRegistryService:_CreateRuntimeId(): TRenderId
	local id = HttpService:GenerateGUID(false)
	while self._soa.IndexById[id] ~= nil do
		id = HttpService:GenerateGUID(false)
	end
	return id
end

function RenderRegistryService:_SnapshotPropertyValues(instance: Instance, index: number)
	local soaAny = self._soa :: any
	for _, descriptor: TRenderPropertyDescriptor in ipairs(PROPERTY_DESCRIPTORS) do
		local runtimeColumn = soaAny[descriptor.RuntimeColumn] :: { [number]: any }
		runtimeColumn[index] = descriptor.Read(instance)
	end
end

function RenderRegistryService:_BuildSortedClientVisibleIds(): { TRenderId }
	local visibleIds = {}
	for index = 1, self._soa.Count do
		local id = self._soa.IdsByIndex[index]
		if id ~= nil and self._clientVisibleById[id] == true and self._clientPublishedById[id] == true then
			table.insert(visibleIds, id)
		end
	end

	table.sort(visibleIds, function(leftId, rightId)
		local leftPriority = self._priorityById[leftId] or 0
		local rightPriority = self._priorityById[rightId] or 0
		if leftPriority == rightPriority then
			return leftId < rightId
		end

		return leftPriority > rightPriority
	end)
	return visibleIds
end

function RenderRegistryService:_BuildBootstrapChunk(
	visibleIds: { TRenderId },
	chunkIndex: number,
	chunkCount: number,
	startIndex: number,
	endIndex: number
): TRenderRegistryBootstrapChunk
	local payload: TRenderRegistryBootstrapChunk = {
		ChunkIndex = chunkIndex,
		ChunkCount = chunkCount,
		Count = math.max(0, endIndex - startIndex + 1),
		IdsByIndex = {},
	}
	local payloadAny = payload :: any
	for _, descriptor: TRenderPropertyDescriptor in ipairs(PROPERTY_DESCRIPTORS) do
		payloadAny[descriptor.RuntimeColumn] = {}
	end

	for visibleIndex = startIndex, endIndex do
		local chunkLocalIndex = (visibleIndex - startIndex) + 1
		local id = visibleIds[visibleIndex]
		local registryIndex = self._soa.IndexById[id]
		payload.IdsByIndex[chunkLocalIndex] = id
		for _, descriptor: TRenderPropertyDescriptor in ipairs(PROPERTY_DESCRIPTORS) do
			local payloadColumn = payloadAny[descriptor.RuntimeColumn] :: { [number]: any }
			local runtimeColumn = (self._soa :: any)[descriptor.RuntimeColumn] :: { [number]: any }
			payloadColumn[chunkLocalIndex] = if registryIndex ~= nil then runtimeColumn[registryIndex] else nil
		end
	end

	return payload
end

function RenderRegistryService:_BuildAddedDelta(
	ids: { TRenderId },
	propertyValuesByIdByKey: { [string]: { [TRenderId]: any } }?
): TRenderRegistryDelta?
	local delta: TRenderRegistryDelta = {
		AddedCount = 0,
		AddedIdsByIndex = {},
	}
	local deltaAny = delta :: any
	for _, descriptor: TRenderPropertyDescriptor in ipairs(PROPERTY_DESCRIPTORS) do
		deltaAny[descriptor.DeltaColumn] = {}
	end

	local addedIdsByIndex = delta.AddedIdsByIndex :: { TRenderId }
	local addedCount = 0

	for _, id in ipairs(ids) do
		local index = self._soa.IndexById[id]
		if index ~= nil then
			addedCount += 1
			addedIdsByIndex[addedCount] = id

			for _, descriptor: TRenderPropertyDescriptor in ipairs(PROPERTY_DESCRIPTORS) do
				local deltaColumn = deltaAny[descriptor.DeltaColumn] :: { [number]: any }
				local propertyValueMaps = if propertyValuesByIdByKey ~= nil then propertyValuesByIdByKey[descriptor.Key] else nil
				if propertyValueMaps ~= nil then
					deltaColumn[addedCount] = propertyValueMaps[id]
				else
					deltaColumn[addedCount] =
						((self._soa :: any)[descriptor.RuntimeColumn] :: { [number]: any })[index]
				end
			end
		end
	end

	if addedCount == 0 then
		return nil
	end

	delta.AddedCount = addedCount
	return delta
end

function RenderRegistryService:_StageAddedOrUpdatedIds(ids: { TRenderId }, priority: number?)
	for _, id in ipairs(ids) do
		local stagedPriority = priority or self._priorityById[id] or 0
		self._lastRemovedPriorityById[id] = nil
		for _, bucket in self._stagedDeltasByPriority do
			bucket.RemovedIdsById[id] = nil
			if bucket ~= self._stagedDeltasByPriority[stagedPriority] then
				bucket.AddedIdsById[id] = nil
			end
		end

		local bucket = self._stagedDeltasByPriority[stagedPriority]
		if bucket ~= nil then
			bucket.AddedIdsById[id] = true
		end
	end
end

function RenderRegistryService:_StageRemovedIds(ids: { TRenderId }, priority: number)
	local bucket = self._stagedDeltasByPriority[priority]
	if bucket == nil then
		return
	end

	for _, id in ipairs(ids) do
		for _, stagedBucket in self._stagedDeltasByPriority do
			stagedBucket.AddedIdsById[id] = nil
			if stagedBucket ~= bucket then
				stagedBucket.RemovedIdsById[id] = nil
			end
		end

		self._lastRemovedPriorityById[id] = priority
		bucket.RemovedIdsById[id] = true
	end
end

function RenderRegistryService:_FlushStagedDeltas()
	local maxAddedIds = math.max(1, RenderConfig.ServerProfile.DeltaMaxIdsPerFlush)
	local maxRemovedIds = math.max(1, RenderConfig.ServerProfile.DeltaMaxRemovalsPerFlush)

	for _, priority in ipairs(PRIORITY_ORDER) do
		local bucket = self._stagedDeltasByPriority[priority]
		if bucket == nil then
			continue
		end

		local addedIds = self:_TakeSortedIds(bucket.AddedIdsById, maxAddedIds)
		if #addedIds > 0 then
			local delta = self:_BuildAddedDelta(addedIds)
			if delta ~= nil then
				self:_BroadcastDelta(delta)
			end
		end

		local removedIds = self:_TakeSortedIds(bucket.RemovedIdsById, maxRemovedIds)
		if #removedIds > 0 then
			self:_BroadcastDelta({
				RemovedIds = removedIds,
			})
		end
	end
end

function RenderRegistryService:_TakeSortedIds(idsById: { [TRenderId]: true }, maxCount: number): { TRenderId }
	local ids = {}
	for id in idsById do
		table.insert(ids, id)
	end
	table.sort(ids)

	local takenIds = {}
	local takeCount = math.min(maxCount, #ids)
	for index = 1, takeCount do
		local id = ids[index]
		takenIds[index] = id
		idsById[id] = nil
	end

	return takenIds
end

function RenderRegistryService:_BroadcastDelta(delta: TRenderRegistryDelta)
	local encodedDelta, serializeError = RenderTransportSchema.SerializeDelta(delta)
	if encodedDelta == nil then
		warn(`RenderRegistryService: failed to serialize delta: {serializeError}`)
		return
	end

	for _, player in ipairs(Players:GetPlayers()) do
		if self._bootstrappingPlayers[player] ~= nil then
			self:_QueueDeltaForPlayer(player, delta)
		elseif self._hydratedPlayers[player] == true then
			self._clientSignals.RenderRegistryDelta:Fire(player, encodedDelta)
		end
	end
end

function RenderRegistryService:_QueueDeltaForPlayer(player: Player, delta: TRenderRegistryDelta)
	local queue = self._bootstrappingPlayers[player]
	if queue == nil then
		return
	end

	if delta.AddedIdsByIndex ~= nil then
		local deltaAny = delta :: any
		for addIndex, id in ipairs(delta.AddedIdsByIndex) do
			for _, removedIds in queue.RemovedIdsByPriority do
				removedIds[id] = nil
			end

			queue.AddedIdsById[id] = true
			for _, descriptor: TRenderPropertyDescriptor in ipairs(PROPERTY_DESCRIPTORS) do
				local propertyValuesById = queue.AddedPropertyValuesByKey[descriptor.Key]
				local deltaColumn = deltaAny[descriptor.DeltaColumn] :: { [number]: any }?
				propertyValuesById[id] = if deltaColumn ~= nil then deltaColumn[addIndex] else nil
			end
		end
	end

	if delta.RemovedIds ~= nil then
		for _, id in ipairs(delta.RemovedIds) do
			queue.AddedIdsById[id] = nil
			for _, descriptor: TRenderPropertyDescriptor in ipairs(PROPERTY_DESCRIPTORS) do
				queue.AddedPropertyValuesByKey[descriptor.Key][id] = nil
			end
			local priority = self._lastRemovedPriorityById[id] or self._priorityById[id] or 0
			local removedIdsById = queue.RemovedIdsByPriority[priority]
			if removedIdsById == nil then
				removedIdsById = {}
				queue.RemovedIdsByPriority[priority] = removedIdsById
			end
			removedIdsById[id] = true
		end
	end
end

function RenderRegistryService:_FlushQueuedDelta(player: Player, queue: TBootstrappingQueue)
	local addedIds = {}
	for id in queue.AddedIdsById do
		local isRemoved = false
		for _, removedIdsById in queue.RemovedIdsByPriority do
			if removedIdsById[id] == true then
				isRemoved = true
				break
			end
		end

		if not isRemoved then
			table.insert(addedIds, id)
		end
	end
	table.sort(addedIds, function(leftId, rightId)
		local leftPriority = self._priorityById[leftId] or 0
		local rightPriority = self._priorityById[rightId] or 0
		if leftPriority == rightPriority then
			return leftId < rightId
		end

		return leftPriority > rightPriority
	end)

	local removedIds = {}
	for _, priority in ipairs(PRIORITY_ORDER) do
		local removedIdsById = queue.RemovedIdsByPriority[priority]
		if removedIdsById ~= nil then
			local sortedIds = self:_TakeSortedIds(removedIdsById, math.huge)
			for _, id in ipairs(sortedIds) do
				table.insert(removedIds, id)
			end
		end
	end

	if #addedIds == 0 and #removedIds == 0 then
		return
	end

	local delta = self:_BuildAddedDelta(addedIds, queue.AddedPropertyValuesByKey) or {}
	if #removedIds > 0 then
		delta.RemovedIds = removedIds
	end

	local encodedDelta, serializeError = RenderTransportSchema.SerializeDelta(delta)
	if encodedDelta == nil then
		warn(`RenderRegistryService: failed to serialize queued delta for {player.Name}: {serializeError}`)
		return
	end

	self._clientSignals.RenderRegistryDelta:Fire(player, encodedDelta)
end

function RenderRegistryService:_CreateBootstrappingQueue(): TBootstrappingQueue
	return {
		AddedIdsById = {},
		AddedPropertyValuesByKey = _CreatePropertyValueMapsByKey(),
		RemovedIdsByPriority = _CreateRemovedIdsByPriority(),
	}
end

function RenderRegistryService:_BuildTag(id: TRenderId): string
	return RenderConfig.RegistryTagPrefix .. id
end

function RenderRegistryService:_GetPriorityForInstance(instance: Instance): number
	for root, priority in ROOT_PRIORITY_BY_CONTAINER do
		if instance:IsDescendantOf(root) then
			return priority
		end
	end

	return 0
end

function RenderRegistryService:_IsDescendantOfTrackedRoot(instance: Instance): boolean
	for _, root in ipairs(TRACKED_ROOTS) do
		if instance:IsDescendantOf(root) then
			return true
		end
	end

	return false
end

function RenderRegistryService:_IsClientVisible(instance: Instance): boolean
	for _, root in ipairs(CLIENT_VISIBLE_ROOTS) do
		if instance:IsDescendantOf(root) then
			return true
		end
	end

	return false
end

function RenderRegistryService:_IsTrackedInstance(instance: Instance): boolean
	if RenderCharacterExclusion.IsExcludedInstance(instance) then
		return false
	end

	for _, className in ipairs(RenderConfig.TrackedClassNames) do
		if instance:IsA(className) then
			return true
		end
	end

	return false
end

function RenderRegistryService:_IsPlayerValid(player: Player): boolean
	return typeof(player) == "Instance"
		and player:IsA("Player")
		and player.Parent == Players
end

return RenderRegistryService
