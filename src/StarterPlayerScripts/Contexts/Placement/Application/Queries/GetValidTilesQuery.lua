--!strict

--[=[
    @class GetValidTilesQuery
    Delegates valid placement tile resolution to the placement grid service.

    The command layer uses this wrapper so placement mode can depend on a query object
    instead of calling infrastructure services directly.
    @client
]=]

-- [Dependencies]

-- [Public API]

local GetValidTilesQuery = {}
GetValidTilesQuery.__index = GetValidTilesQuery

--[=[
    Creates a new valid-tile query.
    @within GetValidTilesQuery
    @param gridService any -- The placement grid service that performs tile filtering.
    @return GetValidTilesQuery -- The query instance.
]=]
function GetValidTilesQuery.new(gridService: any)
	local self = setmetatable({}, GetValidTilesQuery)
	self._gridService = gridService
	return self
end

--[=[
    Returns all valid placement coordinates for a structure type.
    @within GetValidTilesQuery
    @param structureType string -- The structure type being placed.
    @param occupiedSet { [string]: boolean } -- Occupied coordinate lookup.
    @return { GridCoord } -- Frozen list of valid coordinates.
]=]
function GetValidTilesQuery:Execute(structureType: string, occupiedSet: { [string]: boolean })
	return self._gridService.GetValidTiles(structureType, occupiedSet)
end

return GetValidTilesQuery
