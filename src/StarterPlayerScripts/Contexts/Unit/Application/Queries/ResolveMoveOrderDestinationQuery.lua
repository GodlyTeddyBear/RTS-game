--!strict

--[=[
    @class ResolveMoveOrderDestinationQuery
    Resolves a mouse snapshot into a direct world hit destination for unit move orders.

    @client
]=]

local ResolveMoveOrderDestinationQuery = {}
ResolveMoveOrderDestinationQuery.__index = ResolveMoveOrderDestinationQuery

-- Creates a query wrapper around the unit runtime screen-point resolver.
function ResolveMoveOrderDestinationQuery.new()
	local self = setmetatable({}, ResolveMoveOrderDestinationQuery)
	return self
end

-- Returns the world hit rebuilt from the snapshot's screen point through the runtime mouse service.
function ResolveMoveOrderDestinationQuery:Execute(runtimeService: any, mouseSnapshot: any): Vector3?
	if runtimeService == nil or type(mouseSnapshot) ~= "table" then
		return nil
	end

	local screenPoint = mouseSnapshot.ScreenPoint
	local camera = mouseSnapshot.Camera
	local rayLength = mouseSnapshot.RayLength
	if typeof(screenPoint) ~= "Vector2" or camera == nil then
		return nil
	end

	return runtimeService:ResolveWorldPointFromScreenPoint(screenPoint, camera, rayLength)
end

return ResolveMoveOrderDestinationQuery
