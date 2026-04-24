--!strict

--[=[
	@class WorldLayoutService
	Resolves authoritative spawn and goal positions from world configuration.
	@server
]=]
local WorldLayoutService = {}
WorldLayoutService.__index = WorldLayoutService

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WorldConfig = require(ReplicatedStorage.Contexts.World.Config.WorldConfig)
local Errors = require(script.Parent.Parent.Parent.Errors)

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

--[=[
	Returns all configured enemy spawn points.
	@within WorldLayoutService
	@return { CFrame } -- The configured spawn points.
]=]
function WorldLayoutService:GetSpawnPoints(): { CFrame }
	local spawnsContainer = _GetZoneContainer(self, "Spawns", Errors.MISSING_SPAWN_PART)

	local spawnMarkers = _CollectNamedBaseParts(spawnsContainer, WorldConfig.SPAWN_PART_NAME)
	assert(#spawnMarkers > 0, Errors.INVALID_SPAWN_PART)

	local randomIndex = Random.new():NextInteger(1, #spawnMarkers)
	local spawnInstance = spawnMarkers[randomIndex]

	return table.freeze({
		spawnInstance.CFrame,
	})
end

--[=[
	Returns the commander goal point.
	@within WorldLayoutService
	@return CFrame -- The goal point enemies should path toward.
]=]
function WorldLayoutService:GetGoalPoint(): CFrame
	local goalsContainer = _GetZoneContainer(self, "Goals", Errors.MISSING_GOAL_PART)

	local goalMarkers = _CollectNamedBaseParts(goalsContainer, WorldConfig.GOAL_PART_NAME)
	assert(#goalMarkers > 0, Errors.INVALID_GOAL_PART)
	local goalInstance = goalMarkers[1]
	return goalInstance.CFrame
end

return WorldLayoutService
