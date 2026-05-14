--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WorldTypes = require(ReplicatedStorage.Contexts.World.Types.WorldTypes)
local Errors = require(script.Parent.Parent.Parent.Errors)

type GridCoord = WorldTypes.GridCoord
type Tile = WorldTypes.Tile
type GridSpec = WorldTypes.GridSpec

local WorldGridService = {}
WorldGridService.__index = WorldGridService

local function _GetCoordKey(coord: GridCoord): string
	return (`{coord.GridId}:{coord.Row}:{coord.Col}`)
end

function WorldGridService.new()
	local self = setmetatable({}, WorldGridService)
	self._tilesByGridId = {} :: { [string]: { Tile } }
	self._tileByCoordKey = {} :: { [string]: Tile }
	self._allTiles = {} :: { Tile }
	self._gridSpecsById = nil :: { [string]: GridSpec }?
	self._gridRuntimeService = nil :: any
	self._isBuilt = false
	return self
end

function WorldGridService:Init(registry: any, _name: string)
	self._gridRuntimeService = registry:Get("WorldGridRuntimeService")
end

function WorldGridService:_EnsureBuilt()
	if self._isBuilt then
		return
	end

	self:Build()
	self._isBuilt = true
end

function WorldGridService:ResetCache()
	local runtimeService = self._gridRuntimeService
	if runtimeService and runtimeService.ResetCache then
		runtimeService:ResetCache()
	end

	self._tilesByGridId = {}
	self._tileByCoordKey = {}
	self._allTiles = {}
	self._gridSpecsById = nil
	self._isBuilt = false
end

function WorldGridService:Build()
	local runtimeService = self._gridRuntimeService
	assert(runtimeService ~= nil, "WorldGridRuntimeService is required")

	local validationCodes = runtimeService:GetValidationCodes()
	local ok, resolvedSpecsOrErr = pcall(function(): { [string]: GridSpec }
		return runtimeService:GetGridSpecs()
	end)
	if not ok then
		local code = resolvedSpecsOrErr
		if code == validationCodes.MissingPart then
			error(Errors.MISSING_PLACEMENT_GRID_PART)
		end
		if code == validationCodes.InvalidDimensions then
			error(Errors.INVALID_PLACEMENT_GRID_DIMENSIONS)
		end
		if code == validationCodes.MissingGridId then
			error(Errors.MISSING_PLACEMENT_GRID_ID)
		end
		if code == validationCodes.DuplicateGridId then
			error(Errors.DUPLICATE_PLACEMENT_GRID_ID)
		end
		if code == validationCodes.OverlappingGrids then
			error(Errors.OVERLAPPING_PLACEMENT_GRIDS)
		end
		error(code)
	end

	local gridSpecsById = resolvedSpecsOrErr :: { [string]: GridSpec }
	self._gridSpecsById = gridSpecsById

	local tilesByGridId = {} :: { [string]: { Tile } }
	local tileByCoordKey = {} :: { [string]: Tile }
	local allTiles = {} :: { Tile }

	for _, spec in ipairs(runtimeService:GetGridSpecList()) do
		local zoneLayout = runtimeService:BuildZoneLayout(spec)
		local tiles = table.create(spec.GridRows * spec.GridCols)

		for row = 1, spec.GridRows do
			for col = 1, spec.GridCols do
				local descriptor = zoneLayout[row][col]
				assert(descriptor ~= nil, "Missing tile descriptor at Row=" .. row .. " Col=" .. col)
				assert(descriptor.Zone ~= "side_pocket" or descriptor.ResourceType ~= nil, "Side pocket tiles must define ResourceType")
				assert(descriptor.Zone == "side_pocket" or descriptor.ResourceType == nil, "Only side pocket tiles can define ResourceType")

				local coord = {
					GridId = spec.GridId,
					Row = row,
					Col = col,
				}
				local tile = {
					Coord = coord,
					WorldPos = runtimeService:CoordToWorld(coord),
					Zone = descriptor.Zone,
					Occupied = false,
					ResourceType = descriptor.ResourceType,
					IsPlacementProhibited = descriptor.IsPlacementProhibited,
				} :: Tile

				local tileIndex = ((row - 1) * spec.GridCols) + col
				tiles[tileIndex] = tile
				tileByCoordKey[_GetCoordKey(coord)] = tile
				table.insert(allTiles, tile)
			end
		end

		tilesByGridId[spec.GridId] = tiles
	end

	self._tilesByGridId = tilesByGridId
	self._tileByCoordKey = tileByCoordKey
	self._allTiles = allTiles
	self._isBuilt = true
end

function WorldGridService:GetTile(coord: GridCoord): Tile?
	self:_EnsureBuilt()
	assert(type(coord) == "table", "coord must be a table")
	assert(type(coord.GridId) == "string", "coord.GridId must be a string")
	assert(type(coord.Row) == "number" and type(coord.Col) == "number", "coord.Row and coord.Col must be numbers")
	return self._tileByCoordKey[_GetCoordKey(coord)]
end

function WorldGridService:GetTiles(coords: { GridCoord }): { Tile? }
	self:_EnsureBuilt()
	local tiles = table.create(#coords)
	for index, coord in ipairs(coords) do
		tiles[index] = self:GetTile(coord)
	end
	return tiles
end

function WorldGridService:GetAllTiles(): { Tile }
	self:_EnsureBuilt()
	return table.clone(self._allTiles)
end

function WorldGridService:GetGridSpecList(): { GridSpec }
	self:_EnsureBuilt()
	return self._gridRuntimeService:GetGridSpecList()
end

function WorldGridService:GetBuildableTiles(): { Tile }
	self:_EnsureBuilt()
	local buildableTiles = {}

	for _, tile in ipairs(self._allTiles) do
		if tile.Zone ~= "blocked" and tile.Zone ~= "lane" and tile.Occupied == false and tile.IsPlacementProhibited == false then
			table.insert(buildableTiles, tile)
		end
	end

	return buildableTiles
end

function WorldGridService:GetExtractionTiles(): { Tile }
	self:_EnsureBuilt()
	local extractionTiles = {}

	for _, tile in ipairs(self._allTiles) do
		if tile.Zone == "side_pocket" and tile.ResourceType ~= nil then
			table.insert(extractionTiles, tile)
		end
	end

	return extractionTiles
end

function WorldGridService:GetLaneTiles(): { Tile }
	self:_EnsureBuilt()
	local laneTiles = {}

	for _, tile in ipairs(self._allTiles) do
		if tile.Zone == "lane" then
			table.insert(laneTiles, tile)
		end
	end

	return laneTiles
end

function WorldGridService:GetOccupiedCoords(): { GridCoord }
	self:_EnsureBuilt()
	local occupiedCoords = {}

	for _, tile in ipairs(self._allTiles) do
		if tile.Occupied == true then
			table.insert(occupiedCoords, tile.Coord)
		end
	end

	return occupiedCoords
end

function WorldGridService:SetOccupied(coord: GridCoord, occupied: boolean): boolean
	self:_EnsureBuilt()
	local tile = self:GetTile(coord)
	if tile == nil then
		return false
	end

	tile.Occupied = occupied
	return true
end

function WorldGridService:SetOccupiedBatch(coords: { GridCoord }, occupied: boolean): boolean
	self:_EnsureBuilt()
	local tiles = table.create(#coords)
	for index, coord in ipairs(coords) do
		local tile = self:GetTile(coord)
		if tile == nil then
			return false
		end
		tiles[index] = tile
	end

	for _, tile in ipairs(tiles) do
		tile.Occupied = occupied
	end

	return true
end

return WorldGridService
