--!strict

local ResolveMoveOrderDestinationQuery = {}
ResolveMoveOrderDestinationQuery.__index = ResolveMoveOrderDestinationQuery

function ResolveMoveOrderDestinationQuery.new()
	local self = setmetatable({}, ResolveMoveOrderDestinationQuery)
	return self
end

function ResolveMoveOrderDestinationQuery:Execute(mouseSnapshot: any): Vector3?
	local worldPoint = if type(mouseSnapshot) == "table" then mouseSnapshot.WorldPoint else nil
	if typeof(worldPoint) ~= "Vector3" then
		return nil
	end

	return worldPoint
end

return ResolveMoveOrderDestinationQuery
