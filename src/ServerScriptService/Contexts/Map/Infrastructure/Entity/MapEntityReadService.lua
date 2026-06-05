--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Result = require(ReplicatedStorage.Utilities.Result)

local MapEntityReadService = {}
MapEntityReadService.__index = MapEntityReadService

local LOCATION_WORLD = "Location"

function MapEntityReadService.new()
	local self = setmetatable({}, MapEntityReadService)
	return self
end

function MapEntityReadService:Init(_registry: any, _name: string)
end

function MapEntityReadService:Start(registry: any, _name: string)
	self._entityContext = registry:Get("EntityContext")
	assert(self._entityContext ~= nil, "MapEntityReadService requires EntityContext in Start")
end

function MapEntityReadService:GetActiveMapEntity(): number?
	local queryResult = self._entityContext:Query(LOCATION_WORLD, {
		FeatureName = "Map",
		Keys = { "ActiveMapTag" },
	})
	if not queryResult.success then
		return nil
	end
	return queryResult.value[1]
end

function MapEntityReadService:GetRuntimeMapInstance(): Model?
	local mapEntity = self:GetActiveMapEntity()
	if mapEntity == nil then
		return nil
	end

	local instanceResult = self._entityContext:Get(LOCATION_WORLD, mapEntity, "Instance", "Map")
	if not instanceResult.success or type(instanceResult.value) ~= "table" then
		return nil
	end
	return instanceResult.value.Model
end

function MapEntityReadService:GetZoneInstance(zoneName: string): Instance?
	local mapEntity = self:GetActiveMapEntity()
	if mapEntity == nil then
		return nil
	end

	for _, zoneEntity in ipairs(self:_GetZoneEntities()) do
		local zoneResult = self._entityContext:Get(LOCATION_WORLD, zoneEntity, "Zone", "Map")
		local zone = if zoneResult.success then zoneResult.value else nil
		if type(zone) == "table" and zone.MapEntity == mapEntity and zone.ZoneName == zoneName then
			return zone.Instance
		end
	end

	return nil
end

function MapEntityReadService:GetSpawnInstance(): BasePart?
	local mapEntity = self:GetActiveMapEntity()
	if mapEntity == nil then
		return nil
	end

	local queryResult = self._entityContext:Query(LOCATION_WORLD, {
		FeatureName = "Map",
		Keys = { "SpawnZoneTag" },
	})
	if not queryResult.success then
		return nil
	end

	for _, zoneEntity in ipairs(queryResult.value) do
		local zoneResult = self._entityContext:Get(LOCATION_WORLD, zoneEntity, "Zone", "Map")
		local zone = if zoneResult.success then zoneResult.value else nil
		if type(zone) ~= "table" or zone.MapEntity ~= mapEntity then
			continue
		end

		local spawnResult = self._entityContext:Get(LOCATION_WORLD, zoneEntity, "Spawn", "Map")
		local spawn = if spawnResult.success then spawnResult.value else nil
		if type(spawn) == "table" and spawn.Instance ~= nil then
			return spawn.Instance
		end
	end

	return nil
end

function MapEntityReadService:GetBaseInstance(): Instance?
	local base = self:_GetBase()
	return if base ~= nil then base.Instance else nil
end

function MapEntityReadService:GetBaseAnchor(): BasePart?
	local base = self:_GetBase()
	return if base ~= nil then base.Anchor else nil
end

function MapEntityReadService:IsRuntimeMapReady(): Result.Result<boolean>
	return Result.Ok(self:GetActiveMapEntity() ~= nil)
end

function MapEntityReadService:_GetBase(): any?
	local mapEntity = self:GetActiveMapEntity()
	if mapEntity == nil then
		return nil
	end

	local baseResult = self._entityContext:Get(LOCATION_WORLD, mapEntity, "Base", "Map")
	return if baseResult.success and type(baseResult.value) == "table" then baseResult.value else nil
end

function MapEntityReadService:_GetZoneEntities(): { number }
	local queryResult = self._entityContext:Query(LOCATION_WORLD, {
		FeatureName = "Map",
		Keys = { "Zone" },
	})
	return if queryResult.success then queryResult.value else {}
end

return MapEntityReadService
