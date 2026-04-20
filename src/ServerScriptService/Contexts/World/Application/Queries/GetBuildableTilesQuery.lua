--!strict

--[=[
	@class GetBuildableTilesQuery
	Reads all buildable world tiles from the authoritative grid service.
	@server
]=]
local GetBuildableTilesQuery = {}
GetBuildableTilesQuery.__index = GetBuildableTilesQuery

--[=[
	Creates a query wrapper around the world grid service.
	@within GetBuildableTilesQuery
	@param worldGridService { GetBuildableTiles: (any) -> { any } } -- Grid service dependency.
	@return GetBuildableTilesQuery -- The new query instance.
]=]
function GetBuildableTilesQuery.new(worldGridService: { GetBuildableTiles: (any) -> { any } })
	local self = setmetatable({}, GetBuildableTilesQuery)
	self._worldGridService = worldGridService
	return self
end

--[=[
	Returns all unoccupied tiles that are not blocked.
	@within GetBuildableTilesQuery
	@return { any } -- The buildable tile list.
]=]
function GetBuildableTilesQuery:Execute()
	return self._worldGridService:GetBuildableTiles()
end

return GetBuildableTilesQuery
