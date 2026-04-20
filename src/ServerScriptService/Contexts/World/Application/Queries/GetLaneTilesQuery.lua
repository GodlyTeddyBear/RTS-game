--!strict

--[=[
	@class GetLaneTilesQuery
	Reads all lane tiles from the authoritative grid service.
	@server
]=]
local GetLaneTilesQuery = {}
GetLaneTilesQuery.__index = GetLaneTilesQuery

--[=[
	Creates a query wrapper around the world grid service.
	@within GetLaneTilesQuery
	@param worldGridService { GetLaneTiles: (any) -> { any } } -- Grid service dependency.
	@return GetLaneTilesQuery -- The new query instance.
]=]
function GetLaneTilesQuery.new(worldGridService: { GetLaneTiles: (any) -> { any } })
	local self = setmetatable({}, GetLaneTilesQuery)
	self._worldGridService = worldGridService
	return self
end

--[=[
	Returns all lane tiles used for path construction.
	@within GetLaneTilesQuery
	@return { any } -- The lane tile list.
]=]
function GetLaneTilesQuery:Execute()
	return self._worldGridService:GetLaneTiles()
end

return GetLaneTilesQuery
