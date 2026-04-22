--!strict

--[[
    Module: PlacementCursorService
    Purpose: Provides client-side coordinate and tile filtering helpers for placement cursor logic.
    Used In System: Called by placement controllers to convert cursor positions into valid grid tiles.
    Boundaries: Owns presentation-facing coordinate filtering only; does not own authoritative world state or placement writes.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlacementConfig = require(ReplicatedStorage.Contexts.Placement.Config.PlacementConfig)
local PlacementGridRuntime = require(script.Parent.Parent.Infrastructure.PlacementGridRuntime)
local WorldTypes = require(ReplicatedStorage.Contexts.World.Types.WorldTypes)

type GridCoord = WorldTypes.GridCoord
type ZoneType = WorldTypes.ZoneType
type GridSpec = WorldTypes.GridSpec

type OccupiedSet = { [string]: boolean }

--[=[
	@class PlacementCursorService
	Provides client-side coordinate and tile filtering helpers for placement cursor logic.
	@client
]=]
local PlacementCursorService = {}

-- [Private Helpers]

-- Builds a stable lookup key for occupancy tables so tile availability checks stay O(1).
local function _GetCoordKey(row: number, col: number): string
	return ("%d_%d"):format(row, col)
end

-- Returns an immutable coordinate table because callers should not mutate cached grid positions.
local function _CloneCoord(row: number, col: number): GridCoord
	return table.freeze({
		row = row,
		col = col,
	})
end

-- [Public API]

--[=[
	Converts a grid coordinate into a world position for preview and ghost placement.
	@within PlacementCursorService
	@param row number -- Grid row to convert.
	@param col number -- Grid column to convert.
	@return Vector3 -- World-space position for the tile center.
]=]
function PlacementCursorService.CoordToWorld(row: number, col: number): Vector3
	return PlacementGridRuntime.CoordToWorld({
		row = row,
		col = col,
	})
end

--[=[
	Converts a world position into a cloned coordinate so callers receive an immutable result.
	@within PlacementCursorService
	@param worldPos Vector3 -- World position to resolve.
	@return GridCoord? -- The resolved coordinate or nil if the position is out of bounds.
]=]
function PlacementCursorService.WorldToCoord(worldPos: Vector3): GridCoord?
	local coord = PlacementGridRuntime.WorldToCoord(worldPos)
	if coord == nil then
		return nil
	end
	return _CloneCoord(coord.row, coord.col)
end

--[=[
	Returns the zone for a coordinate so cursor logic can gate placement by tile type.
	@within PlacementCursorService
	@param row number -- Grid row to inspect.
	@param col number -- Grid column to inspect.
	@return ZoneType? -- The resolved zone or nil when the coordinate is invalid.
]=]
function PlacementCursorService.GetZone(row: number, col: number): ZoneType?
	local descriptor = PlacementGridRuntime.GetTileDescriptor(row, col)
	if descriptor == nil then
		return nil
	end
	return descriptor.zone
end

--[=[
	Returns all unoccupied tiles allowed for the given structure type.
	@within PlacementCursorService
	@param structureType string -- Structure identifier used to look up allowed zones.
	@param occupiedSet OccupiedSet -- Fast lookup table of occupied coordinates.
	@return { GridCoord } -- Immutable list of valid coordinates for placement.
]=]
function PlacementCursorService.GetValidTiles(structureType: string, occupiedSet: OccupiedSet): { GridCoord }
	local allowedZones = PlacementConfig.VALID_ZONE_TYPES[structureType]
	if allowedZones == nil then
		return table.freeze({})
	end

	local allowedZoneSet = {}
	for _, zoneName in ipairs(allowedZones) do
		allowedZoneSet[zoneName] = true
	end

	local spec: GridSpec = PlacementGridRuntime.GetGridSpec()
	local validTiles = {}
	for row = 1, spec.gridRows do
		for col = 1, spec.gridCols do
			local zone = PlacementCursorService.GetZone(row, col)
			local coordKey = _GetCoordKey(row, col)
			if zone ~= nil and allowedZoneSet[zone] == true and occupiedSet[coordKey] ~= true then
				validTiles[#validTiles + 1] = _CloneCoord(row, col)
			end
		end
	end

	return table.freeze(validTiles)
end

-- [Public API]

return table.freeze(PlacementCursorService)
