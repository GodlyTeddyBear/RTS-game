--!strict

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local CoroutineScheduler = require(ReplicatedStorage.Utilities.CoroutineScheduler)
local Janitor = require(ReplicatedStorage.Packages.Janitor)
local RenderConfig = require(ReplicatedStorage.Contexts.Render.Config.RenderConfig)
local RenderPropertyRegistry = require(ReplicatedStorage.Contexts.Render.RenderPropertyRegistry)
local RenderRingQueue = require(script.Parent.RenderRingQueue)
local RenderTypes = require(ReplicatedStorage.Contexts.Render.Types.RenderTypes)

type TRenderId = RenderTypes.TRenderId
type TRenderRegistryClientSoA = RenderTypes.TRenderRegistryClientSoA
type TRenderPropertyDescriptor = RenderPropertyRegistry.TRenderPropertyDescriptor
type TScheduler = CoroutineScheduler.SchedulerType
type TRingQueue<T> = RenderRingQueue.RingQueue<T>

local PROPERTY_DESCRIPTORS = RenderPropertyRegistry.GetDescriptors()

local RenderProfileService = {}
RenderProfileService.__index = RenderProfileService

function RenderProfileService.new(renderRegistryClientService: any)
	local self = setmetatable({}, RenderProfileService)
	self._janitor = Janitor.new()
	self._renderRegistryClientService = renderRegistryClientService
	self._scheduler = CoroutineScheduler.new(RenderConfig.ClientProfile.ApplyBudgetSeconds) :: TScheduler
	self._dirtyIdsById = {} :: { [TRenderId]: true }
	self._dirtyIdQueue = RenderRingQueue.new() :: TRingQueue<TRenderId>
	self._workerRunning = false
	self._appliedIdsById = {} :: { [TRenderId]: true }
	return self
end

function RenderProfileService:Start()
	self:_ApplyLightingProfile()
	self:_StartScheduler()
	self:_TrackRegistryEntries()
	self:_QueueCurrentRegistryEntries()
end

function RenderProfileService:Destroy()
	if self._scheduler ~= nil then
		self._scheduler:Destroy()
		self._scheduler = nil
	end
	table.clear(self._dirtyIdsById)
	self._dirtyIdQueue:Clear()
	table.clear(self._appliedIdsById)
	self._janitor:Destroy()
end

function RenderProfileService:_ApplyLightingProfile()
	for propertyName, propertyValue in RenderConfig.ClientProfile.Lighting do
		(Lighting :: any)[propertyName] = propertyValue
	end
end

function RenderProfileService:_StartScheduler()
	self._janitor:Add(RunService.Heartbeat:Connect(function()
		if self._scheduler ~= nil then
			self._scheduler:Step()
		end
	end), "Disconnect")
end

function RenderProfileService:_TrackRegistryEntries()
	self._janitor:Add(self._renderRegistryClientService:ObserveEntryChanged(function(id: TRenderId)
		self:_EnqueueApplyById(id)
	end), "Disconnect")
	self._janitor:Add(self._renderRegistryClientService:ObserveEntryRemoved(function(id: TRenderId)
		self._dirtyIdsById[id] = nil
	end), "Disconnect")
end

function RenderProfileService:_QueueCurrentRegistryEntries()
	local registrySoA = self._renderRegistryClientService:GetRegistrySoA() :: TRenderRegistryClientSoA
	for index = 1, registrySoA.Count do
		local id = registrySoA.IdsByIndex[index]
		if id ~= nil then
			self:_EnqueueApplyById(id)
		end
	end
end

function RenderProfileService:_EnqueueApplyById(id: TRenderId)
	if self._appliedIdsById[id] == true then
		return
	end
	if self._dirtyIdsById[id] == true then
		return
	end

	self._dirtyIdsById[id] = true
	self._dirtyIdQueue:Push(id)
	if self._workerRunning then
		return
	end

	self._workerRunning = true
	self._scheduler:Add(function()
		self:_DrainDirtyQueue()
	end)
end

function RenderProfileService:_DrainDirtyQueue()
	local processedCount = 0
	local yieldEveryIds = math.max(1, RenderConfig.ClientProfile.ApplyYieldEveryIds)

	while not self._dirtyIdQueue:IsEmpty() do
		local id = self._dirtyIdQueue:Pop()
		if id ~= nil then
			self._dirtyIdsById[id] = nil
			self:_ApplyById(id)
			processedCount += 1
			if processedCount % yieldEveryIds == 0 then
				self._scheduler:Yield()
			end
		end
	end

	self._workerRunning = false
end

function RenderProfileService:_ApplyById(id: TRenderId)
	if self._appliedIdsById[id] == true then
		return
	end

	local instance = self._renderRegistryClientService:GetInstanceById(id)
	if instance == nil then
		return
	end

	if not instance:IsDescendantOf(Workspace) then
		return
	end

	for _, descriptor: TRenderPropertyDescriptor in ipairs(PROPERTY_DESCRIPTORS) do
		descriptor.ApplyClient(instance, self._renderRegistryClientService:GetPropertyValueById(descriptor.Key, id))
	end

	self._appliedIdsById[id] = true
end

return RenderProfileService
