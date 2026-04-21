--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlacementConfig = require(ReplicatedStorage.Contexts.Placement.Config.PlacementConfig)
local WorldConfig = require(ReplicatedStorage.Contexts.World.Config.WorldConfig)
local WorldTypes = require(ReplicatedStorage.Contexts.World.Types.WorldTypes)

type GridCoord = WorldTypes.GridCoord
type ZoneType = WorldTypes.ZoneType

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
	return WorldConfig.WORLD_ORIGIN:PointToWorldSpace(Vector3.new((col - 1) * WorldConfig.TILE_SIZE, 0, (row - 1) * WorldConfig.TILE_SIZE))
end

function PlacementCursorService.WorldToCoord(worldPos: Vector3): GridCoord?
	local localPos = WorldConfig.WORLD_ORIGIN:PointToObjectSpace(worldPos)
	local col = math.floor(localPos.X / WorldConfig.TILE_SIZE) + 1
	local row = math.floor(localPos.Z / WorldConfig.TILE_SIZE) + 1

	if row < 1 or row > WorldConfig.GRID_ROWS then
		return nil
	end

	if col < 1 or col > WorldConfig.GRID_COLS then
		return nil
	end

	return _CloneCoord(row, col)
end

function PlacementCursorService.GetZone(row: number, col: number): ZoneType?
	local zoneRow = WorldConfig.ZONE_LAYOUT[row]
	if zoneRow == nil then
		return nil
	end

	local descriptor = zoneRow[col]
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

	local validTiles = {}
	for row = 1, WorldConfig.GRID_ROWS do
		for col = 1, WorldConfig.GRID_COLS do
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
