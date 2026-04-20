--!strict

--[=[
	@class GetTileQuery
	Reads a single world tile from the authoritative grid service.
	@server
]=]
local GetTileQuery = {}
GetTileQuery.__index = GetTileQuery

--[=[
	Creates a query wrapper around the world grid service.
	@within GetTileQuery
	@param worldGridService { GetTile: (any, any) -> any } -- Grid service dependency.
	@return GetTileQuery -- The new query instance.
]=]
function GetTileQuery.new(worldGridService: { GetTile: (any, any) -> any })
	local self = setmetatable({}, GetTileQuery)
	self._worldGridService = worldGridService
	return self
end

--[=[
	Returns the tile at the requested grid coordinate.
	@within GetTileQuery
	@param coord any -- Grid coordinate to resolve.
	@return any -- The resolved tile, or nil when the lookup fails.
]=]
function GetTileQuery:Execute(coord: any)
	return self._worldGridService:GetTile(coord)
end

return GetTileQuery
