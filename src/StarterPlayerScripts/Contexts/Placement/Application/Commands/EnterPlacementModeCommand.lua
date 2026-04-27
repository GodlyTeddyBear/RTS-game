--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlacementTypes = require(ReplicatedStorage.Contexts.Placement.Types.PlacementTypes)

type GridCoord = PlacementTypes.GridCoord

local function _GetCoordKey(coord: GridCoord?): string?
	if coord == nil then
		return nil
	end
	return ("%d_%d"):format(coord.row, coord.col)
end

local EnterPlacementModeCommand = {}
EnterPlacementModeCommand.__index = EnterPlacementModeCommand

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

function EnterPlacementModeCommand:Execute(state: any, deps: any, structureType: string)
	if state._confirming then
		return
	end

	if state._state == "Active" then
		self._exitPlacementModeCommand:Execute(state, deps)
	end

	local runState = deps.runAtom()
	if runState.state ~= "Prep" then
		return
	end

	deps.gridService.ResetRuntimeCache()

	local occupiedSet = self._buildOccupiedSetQuery:Execute(deps.placementAtom())
	local validTilesResultOk, validTilesOrError = pcall(function()
		return self._getValidTilesQuery:Execute(structureType, occupiedSet)
	end)
	if not validTilesResultOk then
		return
	end

	local validTiles = validTilesOrError
	if #validTiles == 0 then
		return
	end

	state._state = "Active"
	state._structureType = structureType
	state._confirming = false
	state._hoveredCoord = nil
	state._hoveredKey = nil
	state._isHoveredValid = false
	state._runState = runState.state
	state._placementSignature = self._buildPlacementSignatureQuery:Execute(deps.placementAtom())
	state._validTileSet = {}
	state._sessionId += 1

	deps.playerInputController:ToggleContext("Placement", true)

	state._validTiles = validTiles
	for _, coord in ipairs(validTiles) do
		state._validTileSet[_GetCoordKey(coord)] = true
	end

	state._highlightPool:ShowValidTiles(validTiles)

	local ghostOk, ghostOrError = pcall(function()
		return deps.ghostModelModule.new(structureType)
	end)
	if not ghostOk then
		self._exitPlacementModeCommand:Execute(state, deps)
		return
	end

	state._ghost = ghostOrError
	state._ghost:SetValid(false)

	state._sessionJanitor:Destroy()
	state._sessionJanitor = deps.janitorFactory.new()
	state._sessionJanitor:Add(deps.runService.RenderStepped:Connect(function()
		deps.onRenderStepped()
	end), "Disconnect")
	state._sessionJanitor:Add(deps.userInputService.InputBegan:Connect(function(input, gameProcessed)
		deps.onInputBegan(input, gameProcessed)
	end), "Disconnect")

	deps.updateHoverState()
end

return EnterPlacementModeCommand
