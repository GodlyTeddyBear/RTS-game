--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DebugConfig = require(ReplicatedStorage.Config.DebugConfig)
local SpatialQuery = require(ReplicatedStorage.Utilities.SpatialQuery)
local WorldConfig = require(ReplicatedStorage.Contexts.World.Config.WorldConfig)

local Types = require(script.Parent.Types)

type TMouseSnapshot = Types.TMouseSnapshot

local MIN_GROUND_NORMAL_Y = 0.5
local DOWNCAST_HEIGHT = 512
local DOWNCAST_LENGTH = 2048
local DEBUG_VISUALIZATION_ENABLED = DebugConfig.ENABLED == true and DebugConfig.MOUSE_SERVICE_CURSOR_DEBUG == true
local DEBUG_VISUALIZATION_DURATION = if type(DebugConfig.MOUSE_SERVICE_CURSOR_DEBUG_DURATION_SECONDS) == "number"
	then DebugConfig.MOUSE_SERVICE_CURSOR_DEBUG_DURATION_SECONDS
	else 0.15

local Ground = {}

local function _BuildExcludeList(baseExclude: { Instance }?, additionalExclude: { Instance }?): { Instance }
	local excludedInstances = {}

	if baseExclude ~= nil then
		for _, instance in ipairs(baseExclude) do
			excludedInstances[#excludedInstances + 1] = instance
		end
	end

	if additionalExclude ~= nil then
		for _, instance in ipairs(additionalExclude) do
			excludedInstances[#excludedInstances + 1] = instance
		end
	end

	return excludedInstances
end

local function _BuildQueryOptions(excludedInstances: { Instance }): SpatialQuery.TQueryOptions
	local options = SpatialQuery.CreateRaycastOptions({
		FilterType = Enum.RaycastFilterType.Exclude,
		FilterDescendantsInstances = excludedInstances,
		RespectCanCollide = true,
	})

	if not DEBUG_VISUALIZATION_ENABLED then
		return options
	end

	options.Visualization = {
		Enabled = true,
		Duration = DEBUG_VISUALIZATION_DURATION,
	}

	return options
end

local function _IsGridHit(hit: RaycastResult): boolean
	return hit.Instance.Name == WorldConfig.GRID_PART_NAME
end

local function _IsGroundLikeHit(hit: RaycastResult): boolean
	if _IsGridHit(hit) then
		return false
	end

	return hit.Normal:Dot(Vector3.yAxis) >= MIN_GROUND_NORMAL_Y
end

local function _ResolveRayGroundHit(
	mouseSnapshot: TMouseSnapshot,
	baseExclude: { Instance }?
): (RaycastResult?, { Instance }, RaycastResult?)
	local excludedInstances = _BuildExcludeList(baseExclude, nil)
	local firstNonGridHit = nil :: RaycastResult?

	while true do
		local hit = SpatialQuery.Raycast(
			mouseSnapshot.RayOrigin,
			mouseSnapshot.RayDirection * mouseSnapshot.RayLength,
			_BuildQueryOptions(excludedInstances)
		)
		if hit == nil then
			return nil, excludedInstances, firstNonGridHit
		end

		if _IsGridHit(hit) then
			excludedInstances[#excludedInstances + 1] = hit.Instance
			continue
		end

		if firstNonGridHit == nil then
			firstNonGridHit = hit
		end

		if _IsGroundLikeHit(hit) then
			return hit, excludedInstances, firstNonGridHit
		end

		excludedInstances[#excludedInstances + 1] = hit.Instance
	end
end

local function _ResolveDowncastGroundHit(
	candidatePosition: Vector3,
	baseExclude: { Instance }?,
	firstNonGridHit: RaycastResult?
): RaycastResult?
	local downcastExclude = _BuildExcludeList(baseExclude, nil)
	if firstNonGridHit ~= nil then
		downcastExclude[#downcastExclude + 1] = firstNonGridHit.Instance
	end

	local downcastOrigin = candidatePosition + Vector3.yAxis * DOWNCAST_HEIGHT
	local downcastDirection = Vector3.new(0, -DOWNCAST_LENGTH, 0)

	while true do
		local hit = SpatialQuery.Raycast(downcastOrigin, downcastDirection, _BuildQueryOptions(downcastExclude))
		if hit == nil then
			return nil
		end

		if _IsGridHit(hit) then
			downcastExclude[#downcastExclude + 1] = hit.Instance
			continue
		end

		if _IsGroundLikeHit(hit) then
			return hit
		end

		downcastExclude[#downcastExclude + 1] = hit.Instance
	end
end

function Ground.ResolveGroundPointFromSnapshot(
	mouseSnapshot: TMouseSnapshot,
	baseExclude: { Instance }?
): Vector3?
	if type(mouseSnapshot) ~= "table" then
		return nil
	end

	if typeof(mouseSnapshot.RayOrigin) ~= "Vector3" or typeof(mouseSnapshot.RayDirection) ~= "Vector3" then
		return nil
	end

	if typeof(mouseSnapshot.RayLength) ~= "number" then
		return nil
	end

	local groundHit, excludedInstances, firstNonGridHit = _ResolveRayGroundHit(mouseSnapshot, baseExclude)
	if groundHit ~= nil then
		return groundHit.Position
	end

	local candidatePosition = nil :: Vector3?
	if firstNonGridHit ~= nil then
		candidatePosition = firstNonGridHit.Position
	elseif typeof(mouseSnapshot.WorldPoint) == "Vector3" then
		candidatePosition = mouseSnapshot.WorldPoint
	end

	if candidatePosition == nil then
		return nil
	end

	local downcastGroundHit = _ResolveDowncastGroundHit(candidatePosition, excludedInstances, firstNonGridHit)
	if downcastGroundHit == nil then
		return nil
	end

	return downcastGroundHit.Position
end

return table.freeze(Ground)
