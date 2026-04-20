--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WorldConfig = require(ReplicatedStorage.Contexts.World.Config.WorldConfig)

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
	return setmetatable({}, WorldLayoutService)
end

--[=[
	Initializes the layout service during registry setup.
	@within WorldLayoutService
	@param registry any -- Registry instance passed through the lifecycle contract.
	@param name string -- Registered module name.
]=]
function WorldLayoutService:Init(_registry: any, _name: string)
	-- No setup needed in phase 0.
end

--[=[
	Returns all configured enemy spawn points.
	@within WorldLayoutService
	@return { CFrame } -- The configured spawn points.
]=]
function WorldLayoutService:GetSpawnPoints(): { CFrame }
	return WorldConfig.SPAWN_POINTS
end

--[=[
	Returns the commander goal point.
	@within WorldLayoutService
	@return CFrame -- The goal point enemies should path toward.
]=]
function WorldLayoutService:GetGoalPoint(): CFrame
	return WorldConfig.GOAL_POINT
end

return WorldLayoutService
