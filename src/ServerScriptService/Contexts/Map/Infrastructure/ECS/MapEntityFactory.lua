--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Result = require(ReplicatedStorage.Utilities.Result)
local BaseECSEntityFactory = require(ReplicatedStorage.Utilities.BaseECSEntityFactory)
local Ok = Result.Ok

local MapEntityFactory = {}
MapEntityFactory.__index = MapEntityFactory
setmetatable(MapEntityFactory, BaseECSEntityFactory)

export type ZoneMap = { [string]: Instance }

local function _FindFirstNamedBasePart(root: Instance, markerName: string): BasePart?
	if root:IsA("BasePart") and root.Name == markerName then
		return root
	end

	for _, descendant in ipairs(root:GetDescendants()) do
		if descendant:IsA("BasePart") and descendant.Name == markerName then
			return descendant
		end
	end

	return nil
end

local function _FindFirstNamedInstance(root: Instance, markerName: string): Instance?
	if root.Name == markerName then
		return root
	end

	for _, descendant in ipairs(root:GetDescendants()) do
		if descendant.Name == markerName then
			return descendant
		end
	end

	return nil
end

local function _ResolveAnchor(instance: Instance): BasePart?
	if instance:IsA("BasePart") then
		return instance
	end

	if instance:IsA("Model") then
		return instance.PrimaryPart or instance:FindFirstChildWhichIsA("BasePart", true)
	end

	return instance:FindFirstChildWhichIsA("BasePart", true)
end

local function _ResolveCFrame(instance: Instance): CFrame?
	if instance:IsA("BasePart") then
		return instance.CFrame
	end

	if instance:IsA("Model") then
		return instance:GetPivot()
	end

	local anchor = _ResolveAnchor(instance)
	return anchor and anchor.CFrame or nil
end

function MapEntityFactory.new()
	local self = setmetatable(BaseECSEntityFactory.new("Map"), MapEntityFactory)
	self._mapEntity = nil
	self._zoneEntityByName = {} :: { [string]: number }
	return self
end

function MapEntityFactory:_GetComponentRegistryName(): string
	return "MapComponentRegistry"
end

function MapEntityFactory:_OnInit(_registry: any, _name: string, _componentRegistry: any)
	assert(self._components ~= nil and self._components.MapRootComponent ~= nil, "MapEntityFactory: missing MapComponentRegistry components")
	self:_ConfigureSpatialComponents("MapInstanceComponent", "TransformComponent")
end

function MapEntityFactory:CreateMapRoot(mapId: string, templateName: string, mapModel: Model, zonesByName: ZoneMap): number
	self:DeleteActiveMap()
	self:RequireReady()

	local components = self:GetComponentsOrThrow()
	local mapEntity = self:_CreateEntity()

	self:_Set(mapEntity, components.MapRootComponent, {
		MapId = mapId,
		Template = templateName,
		CreatedAt = os.clock(),
	})
	self:SetModelRef(mapEntity, mapModel)
	self:SetTransformCFrame(mapEntity, mapModel:GetPivot())

	self:_SetName(mapEntity, ("RuntimeMap:%s"):format(mapId))
	self._mapEntity = mapEntity
	self._zoneEntityByName = {}

	for zoneName, zoneInstance in pairs(zonesByName) do
		self:_CreateZoneEntity(mapEntity, zoneName, zoneInstance)
	end

	self:_AttachBaseComponent(mapEntity, mapModel)

	return mapEntity
end

function MapEntityFactory:_AttachBaseComponent(mapEntity: number, mapModel: Model)
	local components = self:GetComponentsOrThrow()
	local baseInstance = _FindFirstNamedInstance(mapModel, "Base")
	if baseInstance == nil then
		return
	end

	local anchor = _ResolveAnchor(baseInstance)
	if anchor == nil then
		return
	end

	self:_Set(mapEntity, components.BaseComponent, {
		Instance = baseInstance,
		Anchor = anchor,
	})
	self:_Add(mapEntity, components.BaseZoneTag)
end

function MapEntityFactory:_CreateZoneEntity(mapEntity: number, zoneName: string, zoneInstance: Instance)
	self:RequireReady()

	local components = self:GetComponentsOrThrow()
	local zoneEntity = self:_CreateChildEntity(mapEntity)

	self:_Set(zoneEntity, components.ZoneComponent, {
		ZoneName = zoneName,
		Instance = zoneInstance,
	})
	local zoneCFrame = _ResolveCFrame(zoneInstance)
	if zoneCFrame ~= nil then
		self:SetTransformCFrame(zoneEntity, zoneCFrame)
	end
	self:_SetName(zoneEntity, ("MapZone:%s"):format(zoneName))

	if zoneName == "Spawns" then
		local spawnMarker = _FindFirstNamedBasePart(zoneInstance, "Spawn")
		if spawnMarker ~= nil then
			self:_Set(zoneEntity, components.SpawnComponent, {
				Instance = spawnMarker,
			})
			self:_Add(zoneEntity, components.SpawnZoneTag)
		end
	end

	if zoneName == "Spawn" and zoneInstance:IsA("BasePart") then
		self:_Set(zoneEntity, components.SpawnComponent, {
			Instance = zoneInstance,
		})
		self:_Add(zoneEntity, components.SpawnZoneTag)
	end

	self._zoneEntityByName[zoneName] = zoneEntity
end

function MapEntityFactory:DeleteActiveMap(): boolean
	self:RequireReady()

	local mapEntity = self._mapEntity
	if mapEntity == nil then
		return false
	end

	self:MarkForDestruction(mapEntity)
	self:FlushDestructionQueue()
	self._mapEntity = nil
	self._zoneEntityByName = {}
	return true
end

function MapEntityFactory:GetActiveMapEntity(): number?
	return self._mapEntity
end

function MapEntityFactory:GetMapInstance(): Model?
	self:RequireReady()

	local mapEntity = self._mapEntity
	if mapEntity == nil then
		return nil
	end

	local modelRef = self:_Get(mapEntity, self._components.MapInstanceComponent)
	return modelRef and modelRef.Model or nil
end

function MapEntityFactory:GetZoneInstance(zoneName: string): Instance?
	self:RequireReady()

	local zoneEntity = self._zoneEntityByName[zoneName]
	if zoneEntity == nil then
		return nil
	end

	local zoneData = self:_Get(zoneEntity, self._components.ZoneComponent)
	return zoneData and zoneData.Instance or nil
end

function MapEntityFactory:GetSpawnInstance(): BasePart?
	self:RequireReady()

	local mapEntity = self._mapEntity
	if mapEntity == nil then
		return nil
	end

	local components = self:GetComponentsOrThrow()
	for _, zoneEntity in ipairs(self:CollectQuery(components.SpawnZoneTag)) do
		local parentEntity = self:GetParentEntity(zoneEntity)
		if parentEntity == mapEntity then
			local spawnData = self:_Get(zoneEntity, components.SpawnComponent)
			if spawnData and spawnData.Instance then
				return spawnData.Instance
			end
		end
	end

	return nil
end

function MapEntityFactory:GetBaseInstance(): Instance?
	self:RequireReady()

	local mapEntity = self._mapEntity
	if mapEntity == nil then
		return nil
	end

	local baseData = self:_Get(mapEntity, self._components.BaseComponent)
	return baseData and baseData.Instance or nil
end

function MapEntityFactory:GetBaseAnchor(): BasePart?
	self:RequireReady()

	local mapEntity = self._mapEntity
	if mapEntity == nil then
		return nil
	end

	local baseData = self:_Get(mapEntity, self._components.BaseComponent)
	return baseData and baseData.Anchor or nil
end

function MapEntityFactory:GetMapCFrame(): CFrame?
	local mapEntity = self._mapEntity
	if mapEntity == nil then
		return nil
	end

	return self:GetEntityCFrame(mapEntity)
end

function MapEntityFactory:GetMapPosition(): Vector3?
	local cframe = self:GetMapCFrame()
	return cframe and cframe.Position or nil
end

function MapEntityFactory:GetZoneCFrame(zoneName: string): CFrame?
	local zoneEntity = self._zoneEntityByName[zoneName]
	if zoneEntity == nil then
		return nil
	end

	local transform = self:GetTransform(zoneEntity)
	return transform and transform.CFrame or nil
end

function MapEntityFactory:GetZonePosition(zoneName: string): Vector3?
	local cframe = self:GetZoneCFrame(zoneName)
	return cframe and cframe.Position or nil
end

function MapEntityFactory:IsRuntimeMapReady(): Result.Result<boolean>
	return Ok(self._mapEntity ~= nil)
end

return MapEntityFactory
