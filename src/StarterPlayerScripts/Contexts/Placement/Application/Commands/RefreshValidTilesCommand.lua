--!strict

--[=[
    @class RefreshValidTilesCommand
    Rebuilds the current placement signature, occupied set, and valid tile highlights.

    The placement cursor controller calls this command when synced placement data changes
    so the visible highlight set stays aligned with the authoritative atom.
    @client
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlacementTypes = require(ReplicatedStorage.Contexts.Placement.Types.PlacementTypes)

type GridCoord = PlacementTypes.GridCoord

type PlacementAtom = PlacementTypes.PlacementAtom

-- Builds a stable key for a coordinate so the valid-tile lookup can use string tables.
local function _GetCoordKey(coord: GridCoord?): string?
	if coord == nil then
		return nil
	end
	return ("%d_%d"):format(coord.row, coord.col)
end

local RefreshValidTilesCommand = {}
RefreshValidTilesCommand.__index = RefreshValidTilesCommand

--[=[
    Creates a new refresh-valid-tiles command.
    @within RefreshValidTilesCommand
    @param buildOccupiedSetQuery any -- Query used to rebuild the occupied lookup.
    @param buildPlacementSignatureQuery any -- Query used to rebuild the atom signature.
    @param getValidTilesQuery any -- Query used to resolve valid placement tiles.
    @return RefreshValidTilesCommand -- The command instance.
]=]
function RefreshValidTilesCommand.new(buildOccupiedSetQuery: any, buildPlacementSignatureQuery: any, getValidTilesQuery: any)
	local self = setmetatable({}, RefreshValidTilesCommand)
	self._buildOccupiedSetQuery = buildOccupiedSetQuery
	self._buildPlacementSignatureQuery = buildPlacementSignatureQuery
	self._getValidTilesQuery = getValidTilesQuery
	return self
end

--[=[
    Rebuilds the valid tile set for the current placement session.
    @within RefreshValidTilesCommand
    @param state any -- Placement controller session state.
    @param placementAtom PlacementAtom? -- Current placement atom snapshot.
]=]
function RefreshValidTilesCommand:Execute(state: any, placementAtom: PlacementAtom?)
	-- Skip refreshes when there is no active structure to validate against.
	if state._structureType == nil then
		return
	end

	-- Update the signature first so hover updates can detect placement changes cheaply.
	state._placementSignature = self._buildPlacementSignatureQuery:Execute(placementAtom)

	-- Rebuild the occupied lookup before asking the grid service for valid tiles.
	local occupiedSet = self._buildOccupiedSetQuery:Execute(placementAtom)
	local validTiles = self._getValidTilesQuery:Execute(state._structureType, occupiedSet)

	-- Cache both the coordinate list and the coordinate lookup for hover checks.
	state._validTiles = validTiles
	state._validTileSet = {}
	for _, coord in ipairs(validTiles) do
		state._validTileSet[_GetCoordKey(coord)] = true
	end

	-- Repaint the highlights after the session state has been updated.
	state._highlightPool:ShowValidTiles(validTiles)
end

return RefreshValidTilesCommand
