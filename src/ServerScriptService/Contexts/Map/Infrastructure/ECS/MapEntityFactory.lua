--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Result = require(ReplicatedStorage.Utilities.Result)
local LocationECSEntityFactory = require(ReplicatedStorage.Utilities.LocationECSEntityFactory)
local Ok = Result.Ok

local MapEntityFactory = {}
MapEntityFactory.__index = MapEntityFactory
setmetatable(MapEntityFactory, LocationECSEntityFactory)

export type ZoneMap = { [string]: Instance }

function MapEntityFactory.new()
	return setmetatable(LocationECSEntityFactory.new("Map"), MapEntityFactory)
end

function MapEntityFactory:_GetComponentRegistryName(): string
	return "MapComponentRegistry"
end

function MapEntityFactory:_OnInit(_registry: any, _name: string, _componentRegistry: any)
	assert(self._components ~= nil and self._components.MapRootComponent ~= nil, "MapEntityFactory: missing MapComponentRegistry components")
	self:_ConfigureLocationComponents("ZoneComponent", "MapInstanceComponent", "TransformComponent")
end

function MapEntityFactory:CreateMapRoot(mapId: string, templateName: string, mapModel: Model, zonesByName: ZoneMap): number
	self:RequireReady()

	local components = self:GetComponentsOrThrow()
	local mapEntity = self:CreateLocationRoot(("RuntimeMap:%s"):format(mapId), mapModel)

	self:_Set(mapEntity, components.MapRootComponent, {
		MapId = mapId,
		Template = templateName,
		CreatedAt = os.clock(),
	})

	self:RegisterZones(mapEntity, zonesByName)
	self:_AttachBaseComponent(mapEntity, mapModel)

	return mapEntity
end

function MapEntityFactory:_AttachBaseComponent(mapEntity: number, mapModel: Model)
	local components = self:GetComponentsOrThrow()
	local baseInstance = self:_FindNamedDescendant(mapModel, "Base")
	if baseInstance == nil then
		return
	end

	local anchor = self:_ResolveAnchor(baseInstance)
	if anchor == nil then
		return
	end

	self:_Set(mapEntity, components.BaseComponent, {
		Instance = baseInstance,
		Anchor = anchor,
	})
	self:_Add(mapEntity, components.BaseZoneTag)
end

function MapEntityFactory:CreateZoneEntity(mapEntity: number, zoneName: string, zoneInstance: Instance): number
	self:RequireReady()

	local components = self:GetComponentsOrThrow()
	local zoneEntity = LocationECSEntityFactory.CreateZoneEntity(self, mapEntity, zoneName, zoneInstance)

	self:_SetName(zoneEntity, ("MapZone:%s"):format(zoneName))

	if zoneName == "Spawns" then
		local spawnMarker = self:_FindNamedBasePart(zoneInstance, "Spawn")
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

	return zoneEntity
end

function MapEntityFactory:DeleteActiveMap(): boolean
	return self:DeleteActiveLocation()
end

function MapEntityFactory:GetActiveMapEntity(): number?
	return self:GetActiveLocationEntity()
end

function MapEntityFactory:GetMapInstance(): Model?
	return self:GetLocationModel()
end

function MapEntityFactory:GetSpawnInstance(): BasePart?
	self:RequireReady()

	local mapEntity = self:GetActiveLocationEntity()
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

	local mapEntity = self:GetActiveLocationEntity()
	if mapEntity == nil then
		return nil
	end

	local baseData = self:_Get(mapEntity, self._components.BaseComponent)
	return baseData and baseData.Instance or nil
end

function MapEntityFactory:GetBaseAnchor(): BasePart?
	self:RequireReady()

	local mapEntity = self:GetActiveLocationEntity()
	if mapEntity == nil then
		return nil
	end

	local baseData = self:_Get(mapEntity, self._components.BaseComponent)
	return baseData and baseData.Anchor or nil
end

function MapEntityFactory:GetMapCFrame(): CFrame?
	return self:GetLocationCFrame()
end

function MapEntityFactory:GetMapPosition(): Vector3?
	return self:GetLocationPosition()
end

function MapEntityFactory:IsRuntimeMapReady(): Result.Result<boolean>
	return Ok(self:GetActiveLocationEntity() ~= nil)
end

return MapEntityFactory
