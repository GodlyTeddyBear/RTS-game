--!strict

--[=[
    @class EnterPlacementModeCommand
    Enters placement mode after validating the requested structure and available tiles.

    The placement cursor controller uses this command to reset cursor state, build the
    valid tile set, create the preview ghost, and subscribe to session-specific inputs.
    @client
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlacementFootprintResolver = require(ReplicatedStorage.Contexts.Placement.PlacementFootprintResolver)
local PlacementTypes = require(ReplicatedStorage.Contexts.Placement.Types.PlacementTypes)
local CanPlaceInRunState = require(script.Parent.Parent.CanPlaceInRunState)

type GridCoord = PlacementTypes.GridCoord

-- Builds a stable key for the hovered coordinate so session state can track it in tables.
local function _GetCoordKey(coord: GridCoord?): string?
	if coord == nil then
		return nil
	end
	return `{coord.GridId}:{coord.Row}:{coord.Col}`
end

local EnterPlacementModeCommand = {}
EnterPlacementModeCommand.__index = EnterPlacementModeCommand

--[=[
    Creates a new enter-placement command.
    @within EnterPlacementModeCommand
    @param exitPlacementModeCommand any -- Command used to tear down an active session.
    @param buildOccupiedSetQuery any -- Query used to build the occupied-tile lookup.
    @param buildPlacementSignatureQuery any -- Query used to detect atom changes.
    @param getValidTilesQuery any -- Query used to resolve valid placement tiles.
    @return EnterPlacementModeCommand -- The command instance.
]=]
function EnterPlacementModeCommand.new(
	exitPlacementModeCommand: any,
	buildOccupiedSetQuery: any,
	buildPlacementSignatureQuery: any,
	getValidTilesQuery: any
)
	local self = setmetatable({}, EnterPlacementModeCommand)
	self._exitPlacementModeCommand = exitPlacementModeCommand
	self._buildOccupiedSetQuery = buildOccupiedSetQuery
	self._buildPlacementSignatureQuery = buildPlacementSignatureQuery
	self._getValidTilesQuery = getValidTilesQuery
	return self
end

--[=[
    Enters placement mode when the structure can be placed.
    @within EnterPlacementModeCommand
    @param state any -- Placement controller session state.
    @param deps any -- Controller dependencies and runtime adapters.
    @param structureType string -- The structure type to preview and place.
]=]
function EnterPlacementModeCommand:Execute(state: any, deps: any, structureType: string)
	-- Ignore re-entry while a confirmation request is still in flight.
	if state._confirming then
		return
	end

	-- Replace the active session before starting a fresh one for the new structure.
	if state._state == "Active" then
		self._exitPlacementModeCommand:Execute(state, deps)
	end

	-- Placement mode is only available while the run is in an active build-allowed phase.
	local runState = deps.runAtom()
	if not CanPlaceInRunState(runState.State) then
		return
	end

	-- The grid runtime is cached across sessions, so clear stale geometry first.
	deps.gridService.ResetRuntimeCache()

	-- Build the occupied lookup from the synced placement atom before filtering tiles.
	local placementAtom = deps.placementAtom()
	local occupiedSet = self._buildOccupiedSetQuery:Execute(placementAtom)
	local footprintCacheLookup = PlacementFootprintResolver.BuildLookup(placementAtom.FootprintCache)
	local validTilesResultOk, validTilesOrError = pcall(function()
		return self._getValidTilesQuery:Execute(footprintCacheLookup, structureType, occupiedSet, 0)
	end)
	if not validTilesResultOk then
		warn(("[PlacementCursor] Failed to resolve valid tiles for '%s': %s"):format(structureType, tostring(validTilesOrError)))
		return
	end

	-- Allow entry even when there are no legal tiles so the player still gets ghost feedback.
	local validTiles = validTilesOrError

	-- Initialize the new placement session state before wiring input handlers.
	state._state = "Active"
	state._structureType = structureType
	state._confirming = false
	state._hoveredCoord = nil
	state._hoveredKey = nil
	state._hoveredFootprintCoords = table.freeze({})
	state._hoveredGroundWorldPos = nil
	state._isHoveredValid = false
	state._runState = runState.State
	state._placementSignature = self._buildPlacementSignatureQuery:Execute(placementAtom)
	state._rotationQuarterTurns = 0
	state._hoveredRotationQuarterTurns = state._rotationQuarterTurns
	state._validTileSet = {}
	state._footprintCacheLookup = footprintCacheLookup
	state._sessionId += 1
	state._placementModeChangedSignal:Fire(true)

	-- Switch the player's input context only after the session state is ready.
	deps.playerInputController:ToggleContext("Placement", true)

	-- Cache the valid tiles so hover state can be checked without recomputing the grid.
	state._validTiles = validTiles
	for _, coord in ipairs(validTiles) do
		state._validTileSet[_GetCoordKey(coord)] = true
	end

	-- Show the valid tile overlay before creating the ghost so both visuals start together.
	state._highlightPool:ShowValidTiles(validTiles)

	-- Ghost creation can fail if the authored model is missing, so guard it separately.
	local ghostOk, ghostOrError = pcall(function()
		return deps.ghostModelModule.new(structureType)
	end)
	if not ghostOk then
		self._exitPlacementModeCommand:Execute(state, deps)
		return
	end

	state._ghost = ghostOrError
	state._ghost:SetRotationQuarterTurns(state._rotationQuarterTurns)
	state._ghost:SetValid(false)

	-- Rebind session-scoped listeners after the ghost and highlights exist.
	state._sessionJanitor:Destroy()
	state._sessionJanitor = deps.janitorFactory.new()
	state._sessionJanitor:Add(
		deps.runService.RenderStepped:Connect(function()
			deps.onRenderStepped()
		end),
		"Disconnect"
	)
	state._sessionJanitor:Add(
		deps.userInputService.InputBegan:Connect(function(input, gameProcessed)
			deps.onInputBegan(input, gameProcessed)
		end),
		"Disconnect"
	)

	-- Sync the initial hover state so the ghost and highlights match the current cursor.
	deps.updateHoverState()
end

return EnterPlacementModeCommand
