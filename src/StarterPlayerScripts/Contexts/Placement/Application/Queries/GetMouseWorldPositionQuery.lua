--!strict

--[=[
    @class GetMouseWorldPositionQuery
    Converts the current mouse position into a world-space point under the active camera.

    Placement hover logic uses this query to raycast the cursor into world geometry
    without coupling the controller to raw mouse math.
    @client
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MouseService = require(ReplicatedStorage.Utilities.MouseService)

local GetMouseWorldPositionQuery = {}
GetMouseWorldPositionQuery.__index = GetMouseWorldPositionQuery

--[=[
    Creates a new mouse world-position query.
    @within GetMouseWorldPositionQuery
    @return GetMouseWorldPositionQuery -- The query instance.
]=]
function GetMouseWorldPositionQuery.new()
	local self = setmetatable({}, GetMouseWorldPositionQuery)
	self._mouseService = MouseService.new()
	return self
end

--[=[
    Resolves the mouse cursor against the first non-grid collidable world hit.
    @within GetMouseWorldPositionQuery
    @param camera Camera -- The active camera.
    @return Vector3? -- The world hit point, or nil when no valid hit is found.
]=]
function GetMouseWorldPositionQuery:Execute(camera: Camera, baseExclude: { Instance }?): Vector3?
	local result = self._mouseService:ResolveGroundPoint({
		CameraProvider = function(): Camera
			return camera
		end,
		BaseExclude = baseExclude,
	})
	if not result.success then
		return nil
	end

	return result.value
end

return GetMouseWorldPositionQuery
