--!strict

--[=[
	@class WorldLayoutService
	Resolves authoritative spawn and goal positions from world configuration.
	@server
]=]
local WorldLayoutService = {}
WorldLayoutService.__index = WorldLayoutService

--[=[
	Creates a layout service that proxies to shared world config.
	@within WorldLayoutService
	@return WorldLayoutService -- The new service instance.
]=]
function WorldLayoutService.new()
	local self = setmetatable({}, WorldLayoutService)
	self._gridRuntimeService = nil :: any
	return self
end

--[=[
	Initializes the layout service during registry setup.
	@within WorldLayoutService
	@param registry any -- Registry instance passed through the lifecycle contract.
	@param name string -- Registered module name.
]=]
function WorldLayoutService:Init(registry: any, _name: string)
	self._gridRuntimeService = registry:Get("WorldGridRuntimeService")
end

--[=[
	Returns all configured enemy spawn points.
	@within WorldLayoutService
	@return { CFrame } -- The configured spawn points.
]=]
function WorldLayoutService:GetSpawnPoints(): { CFrame }
	local gridRuntimeService = self._gridRuntimeService
	assert(gridRuntimeService ~= nil, "WorldGridRuntimeService is required")

	local lanePoints = gridRuntimeService:GetLanePoints()
	return table.freeze({
		lanePoints.spawnPoint,
	})
end

--[=[
	Returns the commander goal point.
	@within WorldLayoutService
	@return CFrame -- The goal point enemies should path toward.
]=]
function WorldLayoutService:GetGoalPoint(): CFrame
	local gridRuntimeService = self._gridRuntimeService
	assert(gridRuntimeService ~= nil, "WorldGridRuntimeService is required")

	local lanePoints = gridRuntimeService:GetLanePoints()
	return lanePoints.goalPoint
end

return WorldLayoutService
