--!strict

--[[
    Module: PlacementCursorGridService
    Purpose: Provides client-side coordinate and tile filtering helpers for placement cursor logic.
    Used In System: Called by placement commands and queries to convert cursor positions into valid grid tiles.
    Boundaries: Owns presentation-facing coordinate filtering only; does not own authoritative world state or placement writes.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlacementConfig = require(ReplicatedStorage.Contexts.Placement.Config.PlacementConfig)
local PlacementGridRuntime = require(script.Parent.PlacementGridRuntime)
local WorldTypes = require(ReplicatedStorage.Contexts.World.Types.WorldTypes)

type GridCoord = WorldTypes.GridCoord
type ZoneType = WorldTypes.ZoneType
type GridSpec = WorldTypes.GridSpec
type TileDescriptor = WorldTypes.TileDescriptor

type OccupiedSet = { [string]: boolean }

local PlacementCursorGridService = {}

local function _GetCoordKey(row: number, col: number): string
	return ("%d_%d"):format(row, col)
end

local function _CloneCoord(row: number, col: number): GridCoord
	return table.freeze({
		row = row,
		col = col,
	})
end

function PlacementCursorGridService.CoordToWorld(row: number, col: number): Vector3
	return PlacementGridRuntime.CoordToWorld({
		row = row,
		col = col,
	})
end

function PlacementCursorGridService.WorldToCoord(worldPos: Vector3): GridCoord?
	local coord = PlacementGridRuntime.WorldToCoord(worldPos)
	if coord == nil then
		return nil
	end
	return _CloneCoord(coord.row, coord.col)
end

function PlacementCursorGridService.GetZone(row: number, col: number): ZoneType?
	local descriptor = PlacementGridRuntime.GetTileDescriptor(row, col)
	if descriptor == nil then
		return nil
	end
	return descriptor.zone
end

function PlacementCursorGridService.GetTileDescriptor(row: number, col: number): TileDescriptor?
	return PlacementGridRuntime.GetTileDescriptor(row, col)
end

function PlacementCursorGridService.ResetRuntimeCache()
	PlacementGridRuntime.ResetCache()
end

function PlacementCursorGridService.GetValidTiles(structureType: string, occupiedSet: OccupiedSet): { GridCoord }
	local placementCost = PlacementConfig.STRUCTURE_PLACEMENT_COSTS[structureType]
	if placementCost == nil then
		return table.freeze({})
	end

	local spec: GridSpec = PlacementGridRuntime.GetGridSpec()
	local validTiles = {}
	for row = 1, spec.gridRows do
		for col = 1, spec.gridCols do
			local descriptor = PlacementCursorGridService.GetTileDescriptor(row, col)
			local coordKey = _GetCoordKey(row, col)
			local zone = descriptor and descriptor.zone or nil
			local isZoneDisallowed = zone ~= nil and PlacementConfig.BASE_DISALLOWED_ZONE_TYPES[zone] == true
			local isPlacementProhibited = descriptor ~= nil and descriptor.isPlacementProhibited == true
			local requiresResourceTile = PlacementConfig.REQUIRES_RESOURCE_TILE[structureType] == true
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
