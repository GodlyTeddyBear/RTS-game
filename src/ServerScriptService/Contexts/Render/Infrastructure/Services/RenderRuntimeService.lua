--!strict

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local CoroutineScheduler = require(ReplicatedStorage.Utilities.CoroutineScheduler)
local Janitor = require(ReplicatedStorage.Packages.Janitor)
local RenderConfig = require(ReplicatedStorage.Contexts.Render.Config.RenderConfig)
local RenderPropertyRegistry = require(ReplicatedStorage.Contexts.Render.RenderPropertyRegistry)
local RenderTypes = require(ReplicatedStorage.Contexts.Render.Types.RenderTypes)

type TRenderId = RenderTypes.TRenderId
type TRenderRegistryServerSoA = RenderTypes.TRenderRegistryServerSoA
type TRenderPropertyDescriptor = RenderPropertyRegistry.TRenderPropertyDescriptor
type TScheduler = CoroutineScheduler.SchedulerType

local PROPERTY_DESCRIPTORS = RenderPropertyRegistry.GetDescriptors()

local RenderRuntimeService = {}
RenderRuntimeService.__index = RenderRuntimeService

local function _SerializePropertyValue(value: any): string
	local valueType = typeof(value)
	if valueType == "nil" then
		return "nil"
	end
	if valueType == "boolean" or valueType == "number" or valueType == "string" then
		return `{valueType}:{tostring(value)}`
	end
	if valueType == "Color3" then
		local color = value :: Color3
		return string.format("Color3:%.6f,%.6f,%.6f", color.R, color.G, color.B)
	end
	if valueType == "EnumItem" then
		local enumItem = value :: EnumItem
		return `Enum:{tostring(enumItem.EnumType)}:{enumItem.Value}`
	end

	return `{valueType}:{tostring(value)}`
end

function RenderRuntimeService.new()
	local self = setmetatable({}, RenderRuntimeService)
	self._janitor = Janitor.new()
	self._renderRegistryService = nil
	self._scheduler = CoroutineScheduler.new(RenderConfig.ServerProfile.ApplyBudgetSeconds) :: TScheduler
	self._dirtyPriorityById = {} :: { [TRenderId]: number }
	self._dirtyIdQueuesByPriority = {} :: { [number]: { TRenderId } }
	self._workerRunningByPriority = {} :: { [number]: true }
	self._lastAppliedSignatureById = {} :: { [TRenderId]: string }
	self._lastAppliedInstanceById = {} :: { [TRenderId]: Instance }
	return self
end

function RenderRuntimeService:Init(registry: any, _name: string)
	self._renderRegistryService = registry:Get("RenderRegistryService")
	assert(self._renderRegistryService ~= nil, "RenderRuntimeService: missing RenderRegistryService")
end

function RenderRuntimeService:Start()
	self:_ApplyLightingProfile()
	self:_StartScheduler()
	self:_TrackRegistryEntries()
	self:_QueueCurrentRegistryEntries()
end

function RenderRuntimeService:Destroy()
	if self._scheduler ~= nil then
		self._scheduler:Destroy()
		self._scheduler = nil
	end
	table.clear(self._dirtyPriorityById)
	table.clear(self._dirtyIdQueuesByPriority)
	table.clear(self._workerRunningByPriority)
	table.clear(self._lastAppliedSignatureById)
	table.clear(self._lastAppliedInstanceById)
	self._janitor:Destroy()
end

function RenderRuntimeService:_ApplyLightingProfile()
	for propertyName, propertyValue in RenderConfig.ServerProfile.Lighting do
		(Lighting :: any)[propertyName] = propertyValue
	end
end

function RenderRuntimeService:_StartScheduler()
	self._janitor:Add(RunService.Heartbeat:Connect(function()
		if self._scheduler ~= nil then
			self._scheduler:Step()
		end
	end), "Disconnect")
end

function RenderRuntimeService:_TrackRegistryEntries()
	self._janitor:Add(self._renderRegistryService:ObserveEntryChanged(function(id: TRenderId)
		self:_EnqueueApplyById(id)
	end), "Disconnect")
	self._janitor:Add(self._renderRegistryService:ObserveEntryRemoved(function(id: TRenderId)
		self._dirtyPriorityById[id] = nil
		self._lastAppliedSignatureById[id] = nil
		self._lastAppliedInstanceById[id] = nil
	end), "Disconnect")
end

function RenderRuntimeService:_QueueCurrentRegistryEntries()
	local registrySoA = self._renderRegistryService:GetRegistrySoA() :: TRenderRegistryServerSoA
	for index = 1, registrySoA.Count do
		local id = registrySoA.IdsByIndex[index]
		if id ~= nil then
			self:_EnqueueApplyById(id)
		end
	end
end

function RenderRuntimeService:_EnqueueApplyById(id: TRenderId)
	local priority = self._renderRegistryService:GetPriorityById(id)
	local previousPriority = self._dirtyPriorityById[id]
	if previousPriority == priority then
		return
	end

	self._dirtyPriorityById[id] = priority
	local queue = self._dirtyIdQueuesByPriority[priority]
	if queue == nil then
		queue = {}
		self._dirtyIdQueuesByPriority[priority] = queue
	end
	table.insert(queue, id)

	if self._workerRunningByPriority[priority] == true then
		return
	end

	self._workerRunningByPriority[priority] = true
	self._scheduler:Add(function()
		self:_DrainDirtyQueue(priority)
	end, priority)
end

function RenderRuntimeService:_HasHigherPriorityPending(priority: number): boolean
	for queuedPriority, queue in self._dirtyIdQueuesByPriority do
		if queuedPriority > priority and #queue > 0 then
			return true
		end
	end

	return false
end

function RenderRuntimeService:_DrainDirtyQueue(priority: number)
	local processedCount = 0
	local baseYieldEveryIds = math.max(1, RenderConfig.ServerProfile.ApplyYieldEveryIds)
	local queue = self._dirtyIdQueuesByPriority[priority]

	while queue ~= nil and #queue > 0 do
		local id = table.remove(queue, 1)
		if id ~= nil and self._dirtyPriorityById[id] == priority then
			self._dirtyPriorityById[id] = nil
			self:_ApplyById(id)
			processedCount += 1

			local effectiveYieldEveryIds = if self:_HasHigherPriorityPending(priority) and priority > 0 then 1 else baseYieldEveryIds
			if processedCount % effectiveYieldEveryIds == 0 then
				self._scheduler:Yield()
			end
		end
	end

	self._workerRunningByPriority[priority] = nil
	if queue ~= nil and #queue > 0 then
		self:_EnqueueApplyById(queue[1])
	end
end

function RenderRuntimeService:_BuildPropertySignature(id: TRenderId): string
	local signatureParts = table.create(#PROPERTY_DESCRIPTORS)

	for index, descriptor: TRenderPropertyDescriptor in ipairs(PROPERTY_DESCRIPTORS) do
		local value = self._renderRegistryService:GetPropertyValueById(descriptor.Key, id)
		signatureParts[index] = `{descriptor.Key}={_SerializePropertyValue(value)}`
	end

	return table.concat(signatureParts, "|")
end

function RenderRuntimeService:_ApplyById(id: TRenderId)
	local instance = self._renderRegistryService:GetInstanceById(id)
	if instance == nil then
		self._lastAppliedSignatureById[id] = nil
		self._lastAppliedInstanceById[id] = nil
		return
	end

	if instance:IsDescendantOf(ReplicatedStorage) then
		self._lastAppliedSignatureById[id] = nil
		self._lastAppliedInstanceById[id] = nil
		return
	end

	local signature = self:_BuildPropertySignature(id)
	if self._lastAppliedInstanceById[id] == instance and self._lastAppliedSignatureById[id] == signature then
		self._renderRegistryService:NotifyServerRendered(id)
		return
	end

	for _, descriptor: TRenderPropertyDescriptor in ipairs(PROPERTY_DESCRIPTORS) do
		descriptor.ApplyServer(instance, self._renderRegistryService:GetPropertyValueById(descriptor.Key, id))
	end

	self._lastAppliedSignatureById[id] = signature
	self._lastAppliedInstanceById[id] = instance
	self._renderRegistryService:NotifyServerRendered(id)
end

return RenderRuntimeService
