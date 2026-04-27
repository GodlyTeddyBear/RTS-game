--!strict

local GetValidTilesQuery = {}
GetValidTilesQuery.__index = GetValidTilesQuery

function GetValidTilesQuery.new(gridService: any)
	local self = setmetatable({}, GetValidTilesQuery)
	self._gridService = gridService
	return self
end

function GetValidTilesQuery:Execute(structureType: string, occupiedSet: { [string]: boolean })
	return self._gridService.GetValidTiles(structureType, occupiedSet)
end

return GetValidTilesQuery
