--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlacementConfig = require(ReplicatedStorage.Contexts.Placement.Config.PlacementConfig)
local PlacementGridRuntime = require(script.Parent.Parent.Infrastructure.PlacementGridRuntime)
local WorldTypes = require(ReplicatedStorage.Contexts.World.Types.WorldTypes)

type GridCoord = WorldTypes.GridCoord
type ZoneType = WorldTypes.ZoneType
type GridSpec = WorldTypes.GridSpec

type OccupiedSet = { [string]: boolean }

local PlacementCursorService = {}

local function _GetCoordKey(row: number, col: number): string
	return ("%d_%d"):format(row, col)
end

local function _CloneCoord(row: number, col: number): GridCoord
	return table.freeze({
		row = row,
		col = col,
	})
end

function PlacementCursorService.CoordToWorld(row: number, col: number): Vector3
	return PlacementGridRuntime.CoordToWorld({
		row = row,
		col = col,
	})
end

function PlacementCursorService.WorldToCoord(worldPos: Vector3): GridCoord?
	local coord = PlacementGridRuntime.WorldToCoord(worldPos)
	if coord == nil then
		return nil
	end
	return _CloneCoord(coord.row, coord.col)
end

function PlacementCursorService.GetZone(row: number, col: number): ZoneType?
	local descriptor = PlacementGridRuntime.GetTileDescriptor(row, col)
	if descriptor == nil then
		return nil
	end
	return descriptor.zone
end

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

return table.freeze(PlacementCursorService)
