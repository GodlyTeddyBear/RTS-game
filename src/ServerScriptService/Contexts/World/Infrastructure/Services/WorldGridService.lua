--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WorldConfig = require(ReplicatedStorage.Contexts.World.Config.WorldConfig)
local WorldTypes = require(ReplicatedStorage.Contexts.World.Types.WorldTypes)

type GridCoord = WorldTypes.GridCoord
type Tile = WorldTypes.Tile

--[=[
	@class WorldGridService
	Builds and owns the authoritative in-memory tile grid for the world lane.
	@server
]=]
local WorldGridService = {}
WorldGridService.__index = WorldGridService

local function getTileIndex(row: number, col: number): number
	return ((row - 1) * WorldConfig.GRID_COLS) + col
end

--[=[
	Creates an empty world grid service instance.
	@within WorldGridService
	@return WorldGridService -- The new service instance.
]=]
function WorldGridService.new()
	local self = setmetatable({}, WorldGridService)
	self._tiles = {} :: { Tile }
	return self
end

--[=[
	Builds the world grid during registry initialization.
	@within WorldGridService
	@param registry any -- Registry instance passed through the lifecycle contract.
	@param name string -- Registered module name.
]=]
function WorldGridService:Init(_registry: any, _name: string)
	self:Build()
end

--[=[
	Populates the flat tile array from the zone layout config.
	@within WorldGridService
]=]
function WorldGridService:Build()
	local tiles = table.create(WorldConfig.GRID_ROWS * WorldConfig.GRID_COLS)

	for row = 1, WorldConfig.GRID_ROWS do
		-- Fill one row at a time so the flat index stays aligned with the config layout.
		for col = 1, WorldConfig.GRID_COLS do
			local descriptor = WorldConfig.ZONE_LAYOUT[row][col]
			assert(descriptor ~= nil, "Missing tile descriptor at row=" .. row .. " col=" .. col)
			assert(descriptor.zone ~= "side_pocket" or descriptor.resourceType ~= nil, "Side pocket tiles must define resourceType")
			assert(descriptor.zone == "side_pocket" or descriptor.resourceType == nil, "Only side pocket tiles can define resourceType")

			-- Offset from the authoritative origin so the grid can be moved by config alone.
			local tileCFrame = WorldConfig.WORLD_ORIGIN * CFrame.new((col - 1) * WorldConfig.TILE_SIZE, 0, (row - 1) * WorldConfig.TILE_SIZE)
			local tileIndex = getTileIndex(row, col)

			tiles[tileIndex] = {
				coord = {
					row = row,
					col = col,
				},
				worldPos = tileCFrame.Position,
				zone = descriptor.zone,
				occupied = false,
				resourceType = descriptor.resourceType,
			}
		end
	end

	self._tiles = tiles
end

--[=[
	Returns the tile at the requested grid coordinate.
	@within WorldGridService
	@param coord GridCoord -- Grid coordinate to resolve.
	@return Tile? -- The matching tile, or nil when out of bounds.
]=]
function WorldGridService:GetTile(coord: GridCoord): Tile?
	assert(type(coord) == "table", "coord must be a table")
	assert(type(coord.row) == "number" and type(coord.col) == "number", "coord.row and coord.col must be numbers")

	if coord.row < 1 or coord.row > WorldConfig.GRID_ROWS then
		return nil
	end

	if coord.col < 1 or coord.col > WorldConfig.GRID_COLS then
		return nil
	end

	return self._tiles[getTileIndex(coord.row, coord.col)]
end

--[=[
	Returns a tile by its flat array index.
	@within WorldGridService
	@param index number -- Flat array index.
	@return Tile? -- The matching tile, or nil when the index is invalid.
]=]
function WorldGridService:GetTileByIndex(index: number): Tile?
	return self._tiles[index]
end

--[=[
	Returns a copy of the current tile array.
	@within WorldGridService
	@return { Tile } -- The current tile list.
]=]
function WorldGridService:GetAllTiles(): { Tile }
	return table.clone(self._tiles)
end

--[=[
	Returns all unoccupied tiles that are not blocked.
	@within WorldGridService
	@return { Tile } -- The buildable tile list.
]=]
function WorldGridService:GetBuildableTiles(): { Tile }
	local buildableTiles = {}

	for _, tile in ipairs(self._tiles) do
		if tile.zone ~= "blocked" and tile.occupied == false then
			table.insert(buildableTiles, tile)
		end
	end

	return buildableTiles
end

--[=[
	Returns all side-pocket tiles that have an assigned resource type.
	@within WorldGridService
	@return { Tile } -- The extraction tile list.
]=]
function WorldGridService:GetExtractionTiles(): { Tile }
	local extractionTiles = {}

	for _, tile in ipairs(self._tiles) do
		if tile.zone == "side_pocket" and tile.resourceType ~= nil then
			table.insert(extractionTiles, tile)
		end
	end

	return extractionTiles
end

--[=[
	Returns all lane tiles for downstream pathing or wave routing.
	@within WorldGridService
	@return { Tile } -- The lane tile list.
]=]
function WorldGridService:GetLaneTiles(): { Tile }
	local laneTiles = {}

	for _, tile in ipairs(self._tiles) do
		if tile.zone == "lane" then
			table.insert(laneTiles, tile)
		end
	end

	return laneTiles
end

--[=[
	Marks a tile as occupied or available.
	@within WorldGridService
	@param coord GridCoord -- Grid coordinate to mutate.
	@param occupied boolean -- Occupancy state to apply.
	@return boolean -- Whether the tile existed and was updated.
]=]
function WorldGridService:SetOccupied(coord: GridCoord, occupied: boolean): boolean
	local tile = self:GetTile(coord)
	if tile == nil then
		return false
	end

	tile.occupied = occupied
	return true
end

return WorldGridService
