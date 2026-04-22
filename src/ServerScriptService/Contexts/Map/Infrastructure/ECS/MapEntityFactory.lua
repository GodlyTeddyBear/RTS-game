--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local JECS = require(ReplicatedStorage.Packages.JECS)
local Result = require(ReplicatedStorage.Utilities.Result)
local BaseECSEntityFactory = require(ReplicatedStorage.Utilities.BaseECSEntityFactory)
local Ok = Result.Ok

local MapEntityFactory = {}
MapEntityFactory.__index = MapEntityFactory
setmetatable(MapEntityFactory, { __index = BaseECSEntityFactory })

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

function MapEntityFactory.new()
	local self = setmetatable(BaseECSEntityFactory._new("Map"), MapEntityFactory)
	self._mapEntity = nil
	self._zoneEntityByName = {} :: { [string]: number }
	return self
end

function MapEntityFactory:Init(registry: any, _name: string)
	BaseECSEntityFactory.InitBase(self, registry, "MapComponentRegistry")
	assert(self._components ~= nil and self._components.MapRootComponent ~= nil, "MapEntityFactory: missing MapComponentRegistry components")
end

function MapEntityFactory:CreateMapRoot(mapId: string, templateName: string, mapModel: Model, zonesByName: ZoneMap): number
	self:DeleteActiveMap()
	self:RequireReady()

	local world = self:GetWorldOrThrow()
	local components = self:GetComponentsOrThrow()
	local mapEntity = world:entity()

	world:set(mapEntity, components.MapRootComponent, {
		MapId = mapId,
		Template = templateName,
		CreatedAt = os.clock(),
	})
	world:set(mapEntity, components.MapInstanceComponent, {
		Instance = mapModel,
	})

	world:set(mapEntity, JECS.Name, ("RuntimeMap:%s"):format(mapId))
	self._mapEntity = mapEntity
	self._zoneEntityByName = {}

	for zoneName, zoneInstance in pairs(zonesByName) do
		self:_CreateZoneEntity(mapEntity, zoneName, zoneInstance)
	end

	return mapEntity
end

function MapEntityFactory:_CreateZoneEntity(mapEntity: number, zoneName: string, zoneInstance: Instance)
	self:RequireReady()

	local world = self:GetWorldOrThrow()
	local components = self:GetComponentsOrThrow()
	local zoneEntity = world:entity()

	world:set(zoneEntity, components.ZoneComponent, {
		ZoneName = zoneName,
		Instance = zoneInstance,
	})
	world:add(zoneEntity, JECS.pair(components.ChildOf, mapEntity))
	world:set(zoneEntity, JECS.Name, ("MapZone:%s"):format(zoneName))

	if zoneName == "Goals" then
		local goalMarker = _FindFirstNamedBasePart(zoneInstance, "Goal")
		if goalMarker ~= nil then
			world:set(zoneEntity, components.GoalComponent, {
				Instance = goalMarker,
			})
			world:add(zoneEntity, components.GoalZoneTag)
		end
	end

	if zoneName == "Spawns" then
		local spawnMarker = _FindFirstNamedBasePart(zoneInstance, "Spawn")
		if spawnMarker ~= nil then
			world:set(zoneEntity, components.SpawnComponent, {
				Instance = spawnMarker,
			})
			world:add(zoneEntity, components.SpawnZoneTag)
		end
	end

	if zoneName == "Goal" and zoneInstance:IsA("BasePart") then
		world:set(zoneEntity, components.GoalComponent, {
			Instance = zoneInstance,
		})
		world:add(zoneEntity, components.GoalZoneTag)
	end

	if zoneName == "Spawn" and zoneInstance:IsA("BasePart") then
		world:set(zoneEntity, components.SpawnComponent, {
			Instance = zoneInstance,
		})
		world:add(zoneEntity, components.SpawnZoneTag)
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

	local modelRef = self._world:get(mapEntity, self._components.MapInstanceComponent)
	return modelRef and modelRef.Instance or nil
end

function MapEntityFactory:GetZoneInstance(zoneName: string): Instance?
	self:RequireReady()

	local zoneEntity = self._zoneEntityByName[zoneName]
	if zoneEntity == nil then
		return nil
	end

	local zoneData = self._world:get(zoneEntity, self._components.ZoneComponent)
	return zoneData and zoneData.Instance or nil
end

function MapEntityFactory:GetGoalInstance(): BasePart?
	self:RequireReady()

	local mapEntity = self._mapEntity
	if mapEntity == nil then
		return nil
	end

	local components = self:GetComponentsOrThrow()
	local world = self:GetWorldOrThrow()
	for _, zoneEntity in ipairs(self:CollectQuery(components.GoalZoneTag)) do
		local parentEntity = world:target(zoneEntity, components.ChildOf)
		if parentEntity == mapEntity then
			local goalData = world:get(zoneEntity, components.GoalComponent)
			if goalData and goalData.Instance then
				return goalData.Instance
			end
		end
	end

	return nil
end

function MapEntityFactory:GetSpawnInstance(): BasePart?
	self:RequireReady()

	local mapEntity = self._mapEntity
	if mapEntity == nil then
		return nil
	end

	local components = self:GetComponentsOrThrow()
	local world = self:GetWorldOrThrow()
	for _, zoneEntity in ipairs(self:CollectQuery(components.SpawnZoneTag)) do
		local parentEntity = world:target(zoneEntity, components.ChildOf)
		if parentEntity == mapEntity then
			local spawnData = world:get(zoneEntity, components.SpawnComponent)
			if spawnData and spawnData.Instance then
				return spawnData.Instance
			end
		end
	end

	return nil
end

function MapEntityFactory:IsRuntimeMapReady(): Result.Result<boolean>
	return Ok(self._mapEntity ~= nil)
end

return MapEntityFactory
