--!strict

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local CoroutineScheduler = require(ReplicatedStorage.Utilities.CoroutineScheduler)
local Janitor = require(ReplicatedStorage.Packages.Janitor)
local RenderConfig = require(ReplicatedStorage.Contexts.Render.Config.RenderConfig)
local RenderPropertyRegistry = require(ReplicatedStorage.Contexts.Render.RenderPropertyRegistry)
local RenderTypes = require(ReplicatedStorage.Contexts.Render.Types.RenderTypes)

type TRenderId = RenderTypes.TRenderId
type TRenderRegistryClientSoA = RenderTypes.TRenderRegistryClientSoA
type TRenderPropertyDescriptor = RenderPropertyRegistry.TRenderPropertyDescriptor
type TScheduler = CoroutineScheduler.SchedulerType

local PROPERTY_DESCRIPTORS = RenderPropertyRegistry.GetDescriptors()

local RenderProfileService = {}
RenderProfileService.__index = RenderProfileService

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

function RenderProfileService.new(renderRegistryClientService: any)
	local self = setmetatable({}, RenderProfileService)
	self._janitor = Janitor.new()
	self._renderRegistryClientService = renderRegistryClientService
	self._scheduler = CoroutineScheduler.new(RenderConfig.ClientProfile.ApplyBudgetSeconds) :: TScheduler
	self._dirtyIdsById = {} :: { [TRenderId]: true }
	self._dirtyIdQueue = {} :: { TRenderId }
	self._workerRunning = false
	self._lastAppliedSignatureById = {} :: { [TRenderId]: string }
	self._lastAppliedInstanceById = {} :: { [TRenderId]: Instance }
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
	table.clear(self._dirtyIdQueue)
	table.clear(self._lastAppliedSignatureById)
	table.clear(self._lastAppliedInstanceById)
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
		self._lastAppliedSignatureById[id] = nil
		self._lastAppliedInstanceById[id] = nil
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
	if self._dirtyIdsById[id] == true then
		return
	end

	self._dirtyIdsById[id] = true
	table.insert(self._dirtyIdQueue, id)
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

	while #self._dirtyIdQueue > 0 do
		local id = table.remove(self._dirtyIdQueue, 1)
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

function RenderProfileService:_BuildPropertySignature(id: TRenderId): string
	local signatureParts = table.create(#PROPERTY_DESCRIPTORS)

	for index, descriptor: TRenderPropertyDescriptor in ipairs(PROPERTY_DESCRIPTORS) do
		local value = self._renderRegistryClientService:GetPropertyValueById(descriptor.Key, id)
		signatureParts[index] = `{descriptor.Key}={_SerializePropertyValue(value)}`
	end

	return table.concat(signatureParts, "|")
end

function RenderProfileService:_ApplyById(id: TRenderId)
	local instance = self._renderRegistryClientService:GetInstanceById(id)
	if instance == nil then
		self._lastAppliedSignatureById[id] = nil
		self._lastAppliedInstanceById[id] = nil
		return
	end

	if not instance:IsDescendantOf(Workspace) then
		self._lastAppliedSignatureById[id] = nil
		self._lastAppliedInstanceById[id] = nil
		return
	end

	local signature = self:_BuildPropertySignature(id)
	if self._lastAppliedInstanceById[id] == instance and self._lastAppliedSignatureById[id] == signature then
		return
	end

	for _, descriptor: TRenderPropertyDescriptor in ipairs(PROPERTY_DESCRIPTORS) do
		descriptor.ApplyClient(instance, self._renderRegistryClientService:GetPropertyValueById(descriptor.Key, id))
	end

	self._lastAppliedSignatureById[id] = signature
	self._lastAppliedInstanceById[id] = instance
end

return RenderProfileService
