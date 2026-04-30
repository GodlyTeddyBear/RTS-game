--!strict

--[=[
	@class WorldLayoutService
	Resolves authoritative spawn positions from world configuration.
	@server
]=]
local WorldLayoutService = {}
WorldLayoutService.__index = WorldLayoutService

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WorldConfig = require(ReplicatedStorage.Contexts.World.Config.WorldConfig)
local WorldTypes = require(ReplicatedStorage.Contexts.World.Types.WorldTypes)
local Errors = require(script.Parent.Parent.Parent.Errors)

type SpawnArea = WorldTypes.SpawnArea

local function _CollectNamedBaseParts(container: Instance, markerName: string): { BasePart }
	local parts = {}
	if container:IsA("BasePart") and container.Name == markerName then
		table.insert(parts, container)
	end

	for _, descendant in ipairs(container:GetDescendants()) do
		if descendant:IsA("BasePart") and descendant.Name == markerName then
			table.insert(parts, descendant)
		end
	end

	return parts
end

--[=[
	Creates a layout service that proxies to shared world config.
	@within WorldLayoutService
	@return WorldLayoutService -- The new service instance.
]=]
function WorldLayoutService.new()
	local self = setmetatable({}, WorldLayoutService)
	self._mapContext = nil :: any
	return self
end

--[=[
	Initializes the layout service during registry setup.
	@within WorldLayoutService
	@param registry any -- Registry instance passed through the lifecycle contract.
	@param name string -- Registered module name.
]=]
function WorldLayoutService:Init(_registry: any, _name: string)
end

function WorldLayoutService:Start(registry: any, _name: string)
	self._mapContext = registry:Get("MapContext")
end

local function _GetZoneContainer(self: any, zoneName: string, missingError: string): Instance
	local mapContext = self._mapContext
	assert(mapContext ~= nil, "WorldLayoutService: MapContext dependency is unavailable")

	local zoneResult = mapContext:GetZoneInstance(zoneName)
	assert(zoneResult.success, tostring(zoneResult.message or zoneResult.type or missingError))
	assert(zoneResult.value ~= nil, missingError)

	return zoneResult.value
end

local function _BuildSpawnArea(spawnPart: BasePart): SpawnArea?
	if spawnPart.Size.X <= 0 or spawnPart.Size.Z <= 0 then
		return nil
	end

	return table.freeze({
		CFrame = spawnPart.CFrame,
		Size = spawnPart.Size,
	})
end

--[=[
	Returns all configured enemy spawn areas.
	@within WorldLayoutService
	@return { SpawnArea } -- The configured spawn areas.
]=]
function WorldLayoutService:GetSpawnAreas(): { SpawnArea }
	local spawnsContainer = _GetZoneContainer(self, "Spawns", Errors.MISSING_SPAWN_PART)
	local spawnMarkers = _CollectNamedBaseParts(spawnsContainer, WorldConfig.SPAWN_PART_NAME)
	local spawnAreas = {}

	for _, spawnMarker in ipairs(spawnMarkers) do
		local spawnArea = _BuildSpawnArea(spawnMarker)
		if spawnArea ~= nil then
			table.insert(spawnAreas, spawnArea)
		end
	end

	assert(#spawnAreas > 0, Errors.INVALID_SPAWN_PART)

	return table.freeze(spawnAreas)
end

return WorldLayoutService
