--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SpatialQuery = require(ReplicatedStorage.Utilities.SpatialQuery)
local WorldConfig = require(ReplicatedStorage.Contexts.World.Config.WorldConfig)

local ResolveMoveOrderDestinationQuery = {}
ResolveMoveOrderDestinationQuery.__index = ResolveMoveOrderDestinationQuery

local function _ResolveFirstNonGridHit(mouseSnapshot: any): RaycastResult?
	if type(mouseSnapshot) ~= "table" then
		return nil
	end

	local camera = mouseSnapshot.Camera
	local screenPoint = mouseSnapshot.ScreenPoint
	local rayLength = mouseSnapshot.RayLength
	if
		typeof(camera) ~= "Instance"
		or not camera:IsA("Camera")
		or typeof(screenPoint) ~= "Vector2"
		or typeof(rayLength) ~= "number"
	then
		return nil
	end

	local excludedInstances = {}

	while true do
		local ray = camera:ViewportPointToRay(screenPoint.X, screenPoint.Y, 0)
		local hit = SpatialQuery.Raycast(ray.Origin, ray.Direction * rayLength, SpatialQuery.CreateRaycastOptions({
			FilterType = Enum.RaycastFilterType.Exclude,
			FilterDescendantsInstances = excludedInstances,
			RespectCanCollide = true,
		}))
		if hit == nil then
			return nil
		end

		if hit.Instance.Name ~= WorldConfig.GRID_PART_NAME then
			return hit
		end

		table.insert(excludedInstances, hit.Instance)
	end
end

function ResolveMoveOrderDestinationQuery.new()
	local self = setmetatable({}, ResolveMoveOrderDestinationQuery)
	return self
end

function ResolveMoveOrderDestinationQuery:Execute(mouseSnapshot: any): Vector3?
	local nonGridHit = _ResolveFirstNonGridHit(mouseSnapshot)
	if nonGridHit ~= nil then
		return nonGridHit.Position
	end

	if type(mouseSnapshot) ~= "table" then
		return nil
	end

	local projectedWorldPoint = mouseSnapshot.ProjectedWorldPoint
	if typeof(projectedWorldPoint) == "Vector3" then
		return projectedWorldPoint
	end

	local worldPoint = mouseSnapshot.WorldPoint
	if typeof(worldPoint) == "Vector3" then
		return worldPoint
	end

	return nil
end

return ResolveMoveOrderDestinationQuery
