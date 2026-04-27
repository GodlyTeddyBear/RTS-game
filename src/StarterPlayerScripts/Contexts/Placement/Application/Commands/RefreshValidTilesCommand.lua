--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlacementTypes = require(ReplicatedStorage.Contexts.Placement.Types.PlacementTypes)

type GridCoord = PlacementTypes.GridCoord

type PlacementAtom = PlacementTypes.PlacementAtom

local function _GetCoordKey(coord: GridCoord?): string?
	if coord == nil then
		return nil
	end
	return ("%d_%d"):format(coord.row, coord.col)
end

local RefreshValidTilesCommand = {}
RefreshValidTilesCommand.__index = RefreshValidTilesCommand

function RefreshValidTilesCommand.new(buildOccupiedSetQuery: any, buildPlacementSignatureQuery: any, getValidTilesQuery: any)
	local self = setmetatable({}, RefreshValidTilesCommand)
	self._buildOccupiedSetQuery = buildOccupiedSetQuery
	self._buildPlacementSignatureQuery = buildPlacementSignatureQuery
	self._getValidTilesQuery = getValidTilesQuery
	return self
end

function RefreshValidTilesCommand:Execute(state: any, placementAtom: PlacementAtom?)
	if state._structureType == nil then
		return
	end

	state._placementSignature = self._buildPlacementSignatureQuery:Execute(placementAtom)

	local occupiedSet = self._buildOccupiedSetQuery:Execute(placementAtom)
	local validTiles = self._getValidTilesQuery:Execute(state._structureType, occupiedSet)

	state._validTiles = validTiles
	state._validTileSet = {}
	for _, coord in ipairs(validTiles) do
		state._validTileSet[_GetCoordKey(coord)] = true
	end

	state._highlightPool:ShowValidTiles(validTiles)
end

return RefreshValidTilesCommand
