--!strict

--[=[
	@class WorldLayoutService
	Resolves authoritative spawn and goal positions from world configuration.
	@server
]=]
local WorldLayoutService = {}
WorldLayoutService.__index = WorldLayoutService

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WorldConfig = require(ReplicatedStorage.Contexts.World.Config.WorldConfig)
local Errors = require(script.Parent.Parent.Parent.Errors)

local function _ResolvePath(path: string): Instance?
	local segments = {}
	for segment in string.gmatch(path, "[^%.]+") do
		table.insert(segments, segment)
	end

	if #segments == 0 then
		return nil
	end

	local current: Instance = game
	local segmentIndex = 1
	local first = string.lower(segments[1])
	if first == "game" then
		segmentIndex = 2
	elseif first == "workspace" then
		current = Workspace
		segmentIndex = 2
	end

	for index = segmentIndex, #segments do
		local segment = segments[index]
		local child = current:FindFirstChild(segment)
		if child == nil then
			return nil
		end
		current = child
	end

	return current
end

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
	local goalInstance = _ResolvePath(WorldConfig.GOAL_PART_PATH)
	if goalInstance == nil then
		goalInstance = Workspace:FindFirstChild("Goal", true)
	end
	assert(goalInstance ~= nil, Errors.MISSING_GOAL_PART)
	assert(goalInstance:IsA("BasePart"), Errors.INVALID_GOAL_PART)
	return goalInstance.CFrame
end

return WorldLayoutService
