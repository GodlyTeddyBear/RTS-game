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
	return setmetatable({}, WorldLayoutService)
end

--[=[
	Initializes the layout service during registry setup.
	@within WorldLayoutService
	@param registry any -- Registry instance passed through the lifecycle contract.
	@param name string -- Registered module name.
]=]
function WorldLayoutService:Init(registry: any, _name: string)
	-- No runtime dependencies required for explicit part-path lookup.
end

--[=[
	Returns all configured enemy spawn points.
	@within WorldLayoutService
	@return { CFrame } -- The configured spawn points.
]=]
function WorldLayoutService:GetSpawnPoints(): { CFrame }
	local spawnsContainer = _ResolvePath(WorldConfig.SPAWNS_FOLDER_PATH)
	assert(spawnsContainer ~= nil, Errors.MISSING_SPAWN_PART)

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
	local goalsContainer = _ResolvePath(WorldConfig.GOALS_FOLDER_PATH)
	assert(goalsContainer ~= nil, Errors.MISSING_GOAL_PART)

	local goalMarkers = _CollectNamedBaseParts(goalsContainer, WorldConfig.GOAL_PART_NAME)
	assert(#goalMarkers > 0, Errors.INVALID_GOAL_PART)
	local goalInstance = goalMarkers[1]
	return goalInstance.CFrame
end

return WorldLayoutService
