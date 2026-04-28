--!strict

--[=[
    @class PlacementCursorGridService
    Resolves client-side placement grid coordinates and valid tile filters for cursor logic.

    Placement commands and queries call this service to convert between world positions,
    grid coordinates, and placement eligibility. It owns client-side filtering only and
    does not own authoritative placement state or writes.
    @client
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlacementConfig = require(ReplicatedStorage.Contexts.Placement.Config.PlacementConfig)
local PlacementGridRuntime = require(script.Parent.PlacementGridRuntime)
local WorldTypes = require(ReplicatedStorage.Contexts.World.Types.WorldTypes)

type GridCoord = WorldTypes.GridCoord
type ZoneType = WorldTypes.ZoneType
type GridSpec = WorldTypes.GridSpec
type TileDescriptor = WorldTypes.TileDescriptor

type OccupiedSet = { [string]: boolean }

-- [Private Helpers]

local PlacementCursorGridService = {}

-- Builds a stable key for a grid coordinate so occupied lookups can use string tables.
local function _GetCoordKey(row: number, col: number): string
	return ("%d_%d"):format(row, col)
end

-- Clones a grid coordinate so callers receive a frozen value object instead of runtime state.
local function _CloneCoord(row: number, col: number): GridCoord
	return table.freeze({
		row = row,
		col = col,
	})
end

-- [Public API]

--[=[
    Converts a grid coordinate to world space.
    @within PlacementCursorGridService
    @param row number -- Grid row index.
    @param col number -- Grid column index.
    @return Vector3 -- The world position for the grid coordinate.
]=]
function PlacementCursorGridService.CoordToWorld(row: number, col: number): Vector3
	return PlacementGridRuntime.CoordToWorld({
		row = row,
		col = col,
	})
end

--[=[
    Converts a world position to a frozen grid coordinate.
    @within PlacementCursorGridService
    @param worldPos Vector3 -- The world-space position to resolve.
    @return GridCoord? -- The matching grid coordinate, or nil when outside the grid.
]=]
function PlacementCursorGridService.WorldToCoord(worldPos: Vector3): GridCoord?
	local coord = PlacementGridRuntime.WorldToCoord(worldPos)
	if coord == nil then
		return nil
	end
	return _CloneCoord(coord.row, coord.col)
end

--[=[
    Returns the zone type for a grid tile.
    @within PlacementCursorGridService
    @param row number -- Grid row index.
    @param col number -- Grid column index.
    @return ZoneType? -- The zone type for the tile, or nil if the tile is unavailable.
]=]
function PlacementCursorGridService.GetZone(row: number, col: number): ZoneType?
	local descriptor = PlacementGridRuntime.GetTileDescriptor(row, col)
	if descriptor == nil then
		return nil
	end
	return descriptor.zone
end

--[=[
    Returns the full tile descriptor for a grid coordinate.
    @within PlacementCursorGridService
    @param row number -- Grid row index.
    @param col number -- Grid column index.
    @return TileDescriptor? -- The resolved tile descriptor, or nil if unavailable.
]=]
function PlacementCursorGridService.GetTileDescriptor(row: number, col: number): TileDescriptor?
	return PlacementGridRuntime.GetTileDescriptor(row, col)
end

--[=[
    Clears the runtime grid cache.
    @within PlacementCursorGridService
]=]
function PlacementCursorGridService.ResetRuntimeCache()
	PlacementGridRuntime.ResetCache()
end

--[=[
    Returns all valid placement tiles for a structure type.
    @within PlacementCursorGridService
    @param structureType string -- The structure type being placed.
    @param occupiedSet OccupiedSet -- Precomputed occupied tile lookup.
    @return { GridCoord } -- Frozen list of valid placement coordinates.
]=]
function PlacementCursorGridService.GetValidTiles(structureType: string, occupiedSet: OccupiedSet): { GridCoord }
	local placementCost = PlacementConfig.STRUCTURE_PLACEMENT_COSTS[structureType]
	if placementCost == nil then
		return table.freeze({})
	end

	local spec: GridSpec = PlacementGridRuntime.GetGridSpec()
	local validTiles = {}
	for row = 1, spec.gridRows do
		for col = 1, spec.gridCols do
			-- Resolve the tile descriptor once so every filter checks the same tile state.
			local descriptor = PlacementCursorGridService.GetTileDescriptor(row, col)
			local coordKey = _GetCoordKey(row, col)
			local zone = descriptor and descriptor.zone or nil
			-- Base zone filters and per-structure placement prohibitions are enforced together here.
			local isZoneDisallowed = zone ~= nil and PlacementConfig.BASE_DISALLOWED_ZONE_TYPES[zone] == true
			local isPlacementProhibited = descriptor ~= nil and descriptor.isPlacementProhibited == true
			local requiresResourceTile = PlacementConfig.REQUIRES_RESOURCE_TILE[structureType] == true
			-- Resource-only structures are restricted to side-pocket tiles with a resolved resource type.
			local hasRequiredResourceTile = not requiresResourceTile
				or (descriptor ~= nil and descriptor.zone == "side_pocket" and descriptor.resourceType ~= nil)
			if
				descriptor ~= nil
				and not isZoneDisallowed
				and not isPlacementProhibited
				and hasRequiredResourceTile
				and occupiedSet[coordKey] ~= true
			then
				validTiles[#validTiles + 1] = _CloneCoord(row, col)
			end
		end
	end

	return table.freeze(validTiles)
end

return table.freeze(PlacementCursorGridService)
