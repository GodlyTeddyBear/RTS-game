--!strict

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local GoodSignal = require(ReplicatedStorage.Packages.Goodsignal)
local Janitor = require(ReplicatedStorage.Packages.Janitor)
local Knit = require(ReplicatedStorage.Packages.Knit)
local CoroutineScheduler = require(ReplicatedStorage.Utilities.CoroutineScheduler)
local RenderCharacterExclusion = require(ReplicatedStorage.Contexts.Render.RenderCharacterExclusion)
local RenderConfig = require(ReplicatedStorage.Contexts.Render.Config.RenderConfig)
local RenderPropertyRegistry = require(ReplicatedStorage.Contexts.Render.RenderPropertyRegistry)
local RenderTransportSchema = require(ReplicatedStorage.Contexts.Render.RenderTransportSchema)
local RenderTypes = require(ReplicatedStorage.Contexts.Render.Types.RenderTypes)

type TRenderId = RenderTypes.TRenderId
type TRenderRegistryClientSoA = RenderTypes.TRenderRegistryClientSoA
type TRenderRegistryBootstrapChunk = RenderTypes.TRenderRegistryBootstrapChunk
type TRenderRegistryDelta = RenderTypes.TRenderRegistryDelta
type TRenderPropertyDescriptor = RenderPropertyRegistry.TRenderPropertyDescriptor
type TScheduler = CoroutineScheduler.SchedulerType
type TInboundWorkItem = {
	Kind: "BootstrapChunk" | "Delta",
	Payload: TRenderRegistryBootstrapChunk | TRenderRegistryDelta,
}

local PROPERTY_DESCRIPTORS = RenderPropertyRegistry.GetDescriptors()
local ROOT_PRIORITY_BY_CONTAINER = RenderConfig.RootPriorityByContainer

local function _BuildClientRoots(): { Instance }
	local roots = {}
	for root, priority in ROOT_PRIORITY_BY_CONTAINER do
		if root == Workspace or root == ReplicatedStorage then
			table.insert(roots, root)
		end
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

local CLIENT_ROOTS = _BuildClientRoots()

local RenderRegistryClientService = {}
RenderRegistryClientService.__index = RenderRegistryClientService

local function _CreateClientSoA(): TRenderRegistryClientSoA
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

	return soa :: TRenderRegistryClientSoA
end

local function _CreatePropertyValuesByKeyFromPayload(
	payload: any,
	index: number,
	mode: "Bootstrap" | "Delta"
): { [string]: any }
	local propertyValuesByKey = {}

	for _, descriptor: TRenderPropertyDescriptor in ipairs(PROPERTY_DESCRIPTORS) do
		local columnName = if mode == "Bootstrap" then descriptor.RuntimeColumn else descriptor.DeltaColumn
		local valuesByIndex = payload[columnName] :: { [number]: any }
		propertyValuesByKey[descriptor.Key] = valuesByIndex[index]
	end

	return propertyValuesByKey
end

function RenderRegistryClientService.new()
	local self = setmetatable({}, RenderRegistryClientService)
	self._janitor = Janitor.new()
	self.EntryChanged = GoodSignal.new()
	self.EntryRemoved = GoodSignal.new()
	self._renderContext = nil
	self._scheduler = CoroutineScheduler.new(RenderConfig.ClientProfile.InboundBudgetSeconds) :: TScheduler
	self._soa = _CreateClientSoA()
	self._idByInstance = {} :: { [Instance]: TRenderId }
	self._liveInstancesById = {} :: { [TRenderId]: Instance }
	self._inboundQueue = {} :: { TInboundWorkItem }
	self._inboundWorkerRunning = false
	self._unresolvedIdsById = {} :: { [TRenderId]: true }
	self._resolutionWorkerRunning = false
	return self
end

function RenderRegistryClientService:Start()
	self:_StartScheduler()
	self:_ConnectTransport()
	self:_TrackClientRoots()
	self:_ScanClientRoots()
	self._renderContext:RequestRenderRegistryBootstrap()
end

function RenderRegistryClientService:Destroy()
	if self.EntryChanged ~= nil then
		self.EntryChanged:DisconnectAll()
	end
	if self.EntryRemoved ~= nil then
		self.EntryRemoved:DisconnectAll()
	end

	if self._scheduler ~= nil then
		self._scheduler:Destroy()
		self._scheduler = nil
	end

	self._janitor:Destroy()
	self._renderContext = nil
	table.clear(self._soa.IndexById)
	table.clear(self._soa.IdsByIndex)
	table.clear(self._soa.InstancesByIndex)
	for _, descriptor: TRenderPropertyDescriptor in ipairs(PROPERTY_DESCRIPTORS) do
		table.clear((self._soa :: any)[descriptor.RuntimeColumn])
	end
	self._soa.Count = 0
	table.clear(self._idByInstance)
	table.clear(self._liveInstancesById)
	table.clear(self._inboundQueue)
	table.clear(self._unresolvedIdsById)
end

function RenderRegistryClientService:GetRegistrySoA(): TRenderRegistryClientSoA
	return self._soa
end

function RenderRegistryClientService:GetIndexById(id: TRenderId): number?
	return self._soa.IndexById[id]
end

function RenderRegistryClientService:GetInstanceById(id: TRenderId): Instance?
	local index = self._soa.IndexById[id]
	if index == nil then
		return nil
	end

	return self._soa.InstancesByIndex[index]
end

function RenderRegistryClientService:GetCastShadowById(id: TRenderId): boolean?
	return self:GetPropertyValueById("CastShadow", id)
end

function RenderRegistryClientService:GetPropertyValueById(propertyKey: string, id: TRenderId): any?
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

function RenderRegistryClientService:ObserveEntryChanged(callback: (id: TRenderId) -> ())
	return self.EntryChanged:Connect(callback)
end

function RenderRegistryClientService:ObserveEntryRemoved(callback: (id: TRenderId) -> ())
	return self.EntryRemoved:Connect(callback)
end

function RenderRegistryClientService:HandleBootstrapChunk(payloadBuffer: buffer)
	local payload, decodeError = RenderTransportSchema.DeserializeBootstrapChunk(payloadBuffer)
	if payload == nil then
		warn(`RenderRegistryClientService: failed to decode bootstrap chunk: {decodeError}`)
		return
	end

	self:_EnqueueInboundWork({
		Kind = "BootstrapChunk",
		Payload = payload,
	})
end

function RenderRegistryClientService:HandleDelta(payloadBuffer: buffer)
	local payload, decodeError = RenderTransportSchema.DeserializeDelta(payloadBuffer)
	if payload == nil then
		warn(`RenderRegistryClientService: failed to decode delta: {decodeError}`)
		return
	end

	self:_EnqueueInboundWork({
		Kind = "Delta",
		Payload = payload,
	})
end

function RenderRegistryClientService:_StartScheduler()
	self._janitor:Add(RunService.Heartbeat:Connect(function()
		if self._scheduler ~= nil then
			self._scheduler:Step()
		end
	end), "Disconnect")
end

function RenderRegistryClientService:_ConnectTransport()
	self._renderContext = Knit.GetService("RenderContext")

	self._janitor:Add(self._renderContext.RenderRegistryBootstrapChunk:Connect(function(payloadBuffer: buffer)
		self:HandleBootstrapChunk(payloadBuffer)
	end), "Disconnect")

	self._janitor:Add(self._renderContext.RenderRegistryDelta:Connect(function(payloadBuffer: buffer)
		self:HandleDelta(payloadBuffer)
	end), "Disconnect")
end

function RenderRegistryClientService:_TrackClientRoots()
	for _, root in ipairs(CLIENT_ROOTS) do
		self._janitor:Add(root.DescendantAdded:Connect(function(instance: Instance)
			self:_TrackLiveInstance(instance)
			if next(self._unresolvedIdsById) ~= nil then
				self:_StartResolutionWorker()
			end
		end), "Disconnect")

		self._janitor:Add(root.DescendantRemoving:Connect(function(instance: Instance)
			self:_QueuePotentialInstanceRemoval(instance)
		end), "Disconnect")
	end
end

function RenderRegistryClientService:_ScanClientRoots()
	for _, root in ipairs(CLIENT_ROOTS) do
		for _, descendant in root:GetDescendants() do
			self:_TrackLiveInstance(descendant)
		end
	end

	if next(self._unresolvedIdsById) ~= nil then
		self:_StartResolutionWorker()
	end
end

function RenderRegistryClientService:_EnqueueInboundWork(workItem: TInboundWorkItem)
	table.insert(self._inboundQueue, workItem)
	if self._inboundWorkerRunning then
		return
	end

	self._inboundWorkerRunning = true
	self._scheduler:Add(function()
		self:_DrainInboundQueue()
	end)
end

function RenderRegistryClientService:_DrainInboundQueue()
	local processedCount = 0
	local yieldEveryItems = math.max(1, RenderConfig.ClientProfile.InboundYieldEveryItems)

	while #self._inboundQueue > 0 do
		local workItem = table.remove(self._inboundQueue, 1)
		if workItem.Kind == "BootstrapChunk" then
			self:_ApplyBootstrapChunk(workItem.Payload :: TRenderRegistryBootstrapChunk)
		else
			self:_ApplyDelta(workItem.Payload :: TRenderRegistryDelta)
		end

		processedCount += 1
		if processedCount % yieldEveryItems == 0 then
			self._scheduler:Yield()
		end
	end

	self._inboundWorkerRunning = false
	if next(self._unresolvedIdsById) ~= nil then
		self:_StartResolutionWorker()
	end
end

function RenderRegistryClientService:_ApplyBootstrapChunk(payload: TRenderRegistryBootstrapChunk)
	for addIndex = 1, payload.Count do
		local id = payload.IdsByIndex[addIndex]
		if id ~= nil then
			self:_UpsertById(id, _CreatePropertyValuesByKeyFromPayload(payload :: any, addIndex, "Bootstrap"))
		end
	end
end

function RenderRegistryClientService:_ApplyDelta(payload: TRenderRegistryDelta)
	if payload.AddedIdsByIndex ~= nil then
		local addedCount = payload.AddedCount or #payload.AddedIdsByIndex
		for addIndex = 1, addedCount do
			local id = payload.AddedIdsByIndex[addIndex]
			if id ~= nil then
				self:_UpsertById(id, _CreatePropertyValuesByKeyFromPayload(payload :: any, addIndex, "Delta"))
			end
		end
	end

	if payload.RemovedIds ~= nil then
		for _, id in ipairs(payload.RemovedIds) do
			self:_RemoveById(id)
		end
	end
end

function RenderRegistryClientService:_TrackLiveInstance(instance: Instance)
	if RenderCharacterExclusion.IsExcludedInstance(instance) then
		local existingId = self._idByInstance[instance]
		if existingId ~= nil then
			self._idByInstance[instance] = nil
			if self._liveInstancesById[existingId] == instance then
				self._liveInstancesById[existingId] = nil
			end

			local index = self._soa.IndexById[existingId]
			if index ~= nil then
				self._soa.InstancesByIndex[index] = nil
				self.EntryChanged:Fire(existingId)
			end
		end

		return
	end

	if not self:_IsTrackedInstance(instance) then
		return
	end

	local id = self:_GetRegistryIdFromInstance(instance)
	if id == nil then
		return
	end

	self._idByInstance[instance] = id
	self._liveInstancesById[id] = instance
	self._unresolvedIdsById[id] = nil

	local index = self._soa.IndexById[id]
	if index == nil then
		return
	end

	self._soa.InstancesByIndex[index] = instance
	self.EntryChanged:Fire(id)
end

function RenderRegistryClientService:_QueuePotentialInstanceRemoval(instance: Instance)
	if self._idByInstance[instance] == nil then
		return
	end

	task.defer(function()
		self:_FinalizeInstanceRemoval(instance)
	end)
end

function RenderRegistryClientService:_FinalizeInstanceRemoval(instance: Instance)
	local id = self._idByInstance[instance]
	if id == nil then
		return
	end

	if self:_IsDescendantOfTrackedClientRoot(instance) then
		self:_TrackLiveInstance(instance)
		return
	end

	self._idByInstance[instance] = nil
	if self._liveInstancesById[id] == instance then
		self._liveInstancesById[id] = nil
	end

	local index = self._soa.IndexById[id]
	if index == nil then
		return
	end

	self._soa.InstancesByIndex[index] = nil
	self.EntryChanged:Fire(id)
end

function RenderRegistryClientService:_UpsertById(id: TRenderId, propertyValuesByKey: { [string]: any })
	local index = self._soa.IndexById[id]
	if index == nil then
		index = self._soa.Count + 1
		self._soa.Count = index
		self._soa.IndexById[id] = index
		self._soa.IdsByIndex[index] = id
	end

	for _, descriptor: TRenderPropertyDescriptor in ipairs(PROPERTY_DESCRIPTORS) do
		local runtimeColumn = (self._soa :: any)[descriptor.RuntimeColumn] :: { [number]: any }
		runtimeColumn[index] = propertyValuesByKey[descriptor.Key]
	end

	local liveInstance = self._liveInstancesById[id]
	self._soa.InstancesByIndex[index] = liveInstance
	if liveInstance == nil then
		self._unresolvedIdsById[id] = true
	end

	self.EntryChanged:Fire(id)
end

function RenderRegistryClientService:_RemoveById(id: TRenderId)
	local removeIndex = self._soa.IndexById[id]
	if removeIndex == nil then
		self._unresolvedIdsById[id] = nil
		self._liveInstancesById[id] = nil
		return
	end

	local removedInstance = self._soa.InstancesByIndex[removeIndex]
	local lastIndex = self._soa.Count
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
	self._liveInstancesById[id] = nil
	self._unresolvedIdsById[id] = nil
	self.EntryRemoved:Fire(id)
end

function RenderRegistryClientService:_StartResolutionWorker()
	if self._resolutionWorkerRunning or next(self._unresolvedIdsById) == nil then
		return
	end

	self._resolutionWorkerRunning = true
	self._scheduler:Add(function()
		self:_ResolveUnresolvedIds()
	end)
end

function RenderRegistryClientService:_ResolveUnresolvedIds()
	local yieldEveryItems = math.max(1, RenderConfig.ClientProfile.InboundYieldEveryItems)

	while next(self._unresolvedIdsById) ~= nil do
		local scannedCount = 0

		for _, root in ipairs(CLIENT_ROOTS) do
			for _, descendant in root:GetDescendants() do
				scannedCount += 1
				local id = self:_GetRegistryIdFromInstance(descendant)
				if id ~= nil and self._unresolvedIdsById[id] == true then
					self:_TrackLiveInstance(descendant)
					if next(self._unresolvedIdsById) == nil then
						self._resolutionWorkerRunning = false
						return
					end
				end

				if scannedCount % yieldEveryItems == 0 then
					self._scheduler:Yield()
				end
			end
		end

		self._scheduler:Yield()
	end

	self._resolutionWorkerRunning = false
end

function RenderRegistryClientService:_GetRegistryIdFromInstance(instance: Instance): string?
	local prefix = RenderConfig.RegistryTagPrefix
	for _, tag in ipairs(CollectionService:GetTags(instance)) do
		if string.sub(tag, 1, #prefix) == prefix then
			local id = string.sub(tag, #prefix + 1)
			if id ~= "" then
				return id
			end
		end
	end

	return nil
end

function RenderRegistryClientService:_IsTrackedInstance(instance: Instance): boolean
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

function RenderRegistryClientService:_IsDescendantOfTrackedClientRoot(instance: Instance): boolean
	for _, root in ipairs(CLIENT_ROOTS) do
		if instance:IsDescendantOf(root) then
			return true
		end
	end

	return false
end

return RenderRegistryClientService
