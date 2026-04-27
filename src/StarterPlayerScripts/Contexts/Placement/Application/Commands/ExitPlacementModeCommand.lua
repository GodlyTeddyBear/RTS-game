--!strict

local ExitPlacementModeCommand = {}
ExitPlacementModeCommand.__index = ExitPlacementModeCommand

function ExitPlacementModeCommand.new()
	return setmetatable({}, ExitPlacementModeCommand)
end

function ExitPlacementModeCommand:Execute(state: any, deps: any)
	if state._state ~= "Active" then
		return
	end

	state._state = "Idle"
	state._confirming = false
	state._structureType = nil
	state._hoveredCoord = nil
	state._hoveredKey = nil
	state._isHoveredValid = false
	state._validTiles = table.freeze({})
	state._validTileSet = {}
	state._placementSignature = ""

	deps.playerInputController:ToggleContext("Placement", false)

	state._sessionJanitor:Destroy()
	state._sessionJanitor = deps.janitorFactory.new()

	state._highlightPool:HideAll()

	if state._ghost ~= nil then
		state._ghost:Destroy()
		state._ghost = nil
	end

	state._placementCancelledSignal:Fire()
end

return ExitPlacementModeCommand
