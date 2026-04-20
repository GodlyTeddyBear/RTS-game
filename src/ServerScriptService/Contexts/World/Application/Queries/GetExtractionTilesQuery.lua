--!strict

--[=[
	@class GetExtractionTilesQuery
	Reads all extraction tiles from the authoritative grid service.
	@server
]=]
local GetExtractionTilesQuery = {}
GetExtractionTilesQuery.__index = GetExtractionTilesQuery

--[=[
	Creates a query wrapper around the world grid service.
	@within GetExtractionTilesQuery
	@param worldGridService { GetExtractionTiles: (any) -> { any } } -- Grid service dependency.
	@return GetExtractionTilesQuery -- The new query instance.
]=]
function GetExtractionTilesQuery.new(worldGridService: { GetExtractionTiles: (any) -> { any } })
	local self = setmetatable({}, GetExtractionTilesQuery)
	self._worldGridService = worldGridService
	return self
end

--[=[
	Returns all side-pocket tiles with resource types.
	@within GetExtractionTilesQuery
	@return { any } -- The extraction tile list.
]=]
function GetExtractionTilesQuery:Execute()
	return self._worldGridService:GetExtractionTiles()
end

return GetExtractionTilesQuery
