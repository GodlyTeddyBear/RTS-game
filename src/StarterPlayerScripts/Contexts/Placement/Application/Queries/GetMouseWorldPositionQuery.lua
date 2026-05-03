--!strict

--[=[
    @class GetMouseWorldPositionQuery
    Converts the current mouse position into a world-space point under the active camera.

    Placement hover logic uses this query to raycast the cursor into world geometry
    without coupling the controller to raw mouse math.
    @client
]=]

local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SpatialQuery = require(ReplicatedStorage.Utilities.SpatialQuery)
local WorldConfig = require(ReplicatedStorage.Contexts.World.Config.WorldConfig)

local GetMouseWorldPositionQuery = {}
GetMouseWorldPositionQuery.__index = GetMouseWorldPositionQuery

--[=[
    Creates a new mouse world-position query.
    @within GetMouseWorldPositionQuery
    @return GetMouseWorldPositionQuery -- The query instance.
]=]
function GetMouseWorldPositionQuery.new()
	return setmetatable({}, GetMouseWorldPositionQuery)
end

local function _ResolveFirstNonGridHit(
	origin: Vector3,
	direction: Vector3,
	baseExclude: { Instance }?
): RaycastResult?
	local excludedInstances = {}
	if baseExclude ~= nil then
		for _, instance in ipairs(baseExclude) do
			table.insert(excludedInstances, instance)
		end
	end

	while true do
		local hit = SpatialQuery.Raycast(origin, direction, SpatialQuery.CreateRaycastOptions({
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

--[=[
    Resolves the mouse cursor against the first non-grid collidable world hit.
    @within GetMouseWorldPositionQuery
    @param camera Camera -- The active camera.
    @return Vector3? -- The world hit point, or nil when no valid hit is found.
]=]
function GetMouseWorldPositionQuery:Execute(camera: Camera, baseExclude: { Instance }?): Vector3?
	local mouseLocation = UserInputService:GetMouseLocation()
	local ray = camera:ViewportPointToRay(mouseLocation.X, mouseLocation.Y, 0)
	local hit = _ResolveFirstNonGridHit(ray.Origin, ray.Direction * 2000, baseExclude)
	if hit == nil then
		return nil
	end

	return hit.Position
end

return GetMouseWorldPositionQuery
