--!strict

--[=[
    @class GetMouseWorldPositionQuery
    Converts the current mouse position into a world-space point under the active camera.

    Placement hover logic uses this query to raycast the cursor onto the placement plane
    without coupling the controller to raw mouse math.
    @client
]=]

local UserInputService = game:GetService("UserInputService")

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

--[=[
    Resolves the mouse cursor onto the world plane beneath the camera.
    @within GetMouseWorldPositionQuery
    @param camera Camera -- The active camera.
    @return Vector3? -- The intersection point, or nil when the ray is parallel or behind the camera.
]=]
function GetMouseWorldPositionQuery:Execute(camera: Camera): Vector3?
	local mouseLocation = UserInputService:GetMouseLocation()
	local ray = camera:ViewportPointToRay(mouseLocation.X, mouseLocation.Y, 0)
	if math.abs(ray.Direction.Y) < 1e-5 then
		return nil
	end

	local t = -ray.Origin.Y / ray.Direction.Y
	if t < 0 then
		return nil
	end

	return ray.Origin + ray.Direction * t
end

return GetMouseWorldPositionQuery
