--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local JECS = require(ReplicatedStorage.Packages.JECS)
local Result = require(ReplicatedStorage.Utilities.Result)
local Ok = Result.Ok

local MapEntityFactory = {}
MapEntityFactory.__index = MapEntityFactory

export type ZoneMap = { [string]: Instance }

function MapEntityFactory.new()
	local self = setmetatable({}, MapEntityFactory)
	self._world = nil
	self._components = nil
	self._mapEntity = nil
	self._zoneEntityByName = {} :: { [string]: number }
	return self
end

function MapEntityFactory:Init(registry: any, _name: string)
	self._world = registry:Get("World")
	local componentRegistry = registry:Get("MapComponentRegistry")
	local components = componentRegistry and componentRegistry:GetComponents() or nil
	assert(components ~= nil and components.MapRootComponent ~= nil, "MapEntityFactory: missing MapComponentRegistry components")
	self._components = components
end

function MapEntityFactory:CreateMapRoot(mapId: string, templateName: string, mapModel: Model, zonesByName: ZoneMap): number
	self:DeleteActiveMap()

	local world = self._world
	local components = self._components
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
	local world = self._world
	local components = self._components
	local zoneEntity = world:entity()

	world:set(zoneEntity, components.ZoneComponent, {
		ZoneName = zoneName,
		Instance = zoneInstance,
	})
	world:add(zoneEntity, JECS.pair(components.ChildOf, mapEntity))
	world:set(zoneEntity, JECS.Name, ("MapZone:%s"):format(zoneName))

	if zoneName == "Goal" and zoneInstance:IsA("BasePart") then
		world:set(zoneEntity, components.GoalComponent, {
			Instance = zoneInstance,
		})
		world:add(zoneEntity, components.GoalZoneTag)
	end

	self._zoneEntityByName[zoneName] = zoneEntity
end

function MapEntityFactory:DeleteActiveMap(): boolean
	local mapEntity = self._mapEntity
	if mapEntity == nil then
		return false
	end

	self._world:delete(mapEntity)
	self._mapEntity = nil
	self._zoneEntityByName = {}
	return true
end

function MapEntityFactory:GetActiveMapEntity(): number?
	return self._mapEntity
end

function MapEntityFactory:GetMapInstance(): Model?
	local mapEntity = self._mapEntity
	if mapEntity == nil then
		return nil
	end

	local modelRef = self._world:get(mapEntity, self._components.MapInstanceComponent)
	return modelRef and modelRef.Instance or nil
end

function MapEntityFactory:GetZoneInstance(zoneName: string): Instance?
	local zoneEntity = self._zoneEntityByName[zoneName]
	if zoneEntity == nil then
		return nil
	end

	local zoneData = self._world:get(zoneEntity, self._components.ZoneComponent)
	return zoneData and zoneData.Instance or nil
end

function MapEntityFactory:GetGoalInstance(): BasePart?
	local mapEntity = self._mapEntity
	if mapEntity == nil then
		return nil
	end

	local components = self._components
	for zoneEntity in self._world:query(components.GoalZoneTag) do
		local parentEntity = self._world:target(zoneEntity, components.ChildOf)
		if parentEntity == mapEntity then
			local goalData = self._world:get(zoneEntity, components.GoalComponent)
			if goalData and goalData.Instance then
				return goalData.Instance
			end
		end
	end

	return nil
end

function MapEntityFactory:IsRuntimeMapReady(): Result.Result<boolean>
	return Ok(self._mapEntity ~= nil)
end

return MapEntityFactory
