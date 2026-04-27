--!strict

local UserInputService = game:GetService("UserInputService")

local GetMouseWorldPositionQuery = {}
GetMouseWorldPositionQuery.__index = GetMouseWorldPositionQuery

function GetMouseWorldPositionQuery.new()
	return setmetatable({}, GetMouseWorldPositionQuery)
end

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
