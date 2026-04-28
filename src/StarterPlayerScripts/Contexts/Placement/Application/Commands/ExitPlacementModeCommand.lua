--!strict

--[=[
    @class ExitPlacementModeCommand
    Exits placement mode and clears the active client-side placement session.

    The placement cursor controller uses this command to tear down visuals, reset state,
    and notify listeners that the session has ended.
    @client
]=]

local ExitPlacementModeCommand = {}
ExitPlacementModeCommand.__index = ExitPlacementModeCommand

--[=[
    Creates a new exit-placement command.
    @within ExitPlacementModeCommand
    @return ExitPlacementModeCommand -- The command instance.
]=]
function ExitPlacementModeCommand.new()
	return setmetatable({}, ExitPlacementModeCommand)
end

--[=[
    Leaves placement mode and resets controller session state.
    @within ExitPlacementModeCommand
    @param state any -- Placement controller session state.
    @param deps any -- Controller dependencies and runtime adapters.
]=]
function ExitPlacementModeCommand:Execute(state: any, deps: any)
	-- Ignore redundant exits when placement is already inactive.
	if state._state ~= "Active" then
		return
	end

	-- Reset the session state before tearing down listeners and visuals.
	state._state = "Idle"
	state._confirming = false
	state._structureType = nil
	state._hoveredCoord = nil
	state._hoveredKey = nil
	state._isHoveredValid = false
	state._validTiles = table.freeze({})
	state._validTileSet = {}
	state._placementSignature = ""

	-- Restore the player's normal input context after the session state is cleared.
	deps.playerInputController:ToggleContext("Placement", false)

	-- Replace the session janitor so stale connections cannot fire after teardown.
	state._sessionJanitor:Destroy()
	state._sessionJanitor = deps.janitorFactory.new()

	-- Clear highlights before destroying the ghost so the cursor disappears in one pass.
	state._highlightPool:HideAll()

	if state._ghost ~= nil then
		-- The ghost model owns its own cleanup because it may have internal descendants.
		state._ghost:Destroy()
		state._ghost = nil
	end

	-- Notify any listeners that placement mode ended so they can reset their UI state.
	state._placementCancelledSignal:Fire()
end

return ExitPlacementModeCommand
