--!strict

--[=[
    @class TogglePlacementModeCommand
    Switches placement mode on or off for a specific structure type.

    The placement cursor controller uses this command to keep the toggle behavior
    symmetrical: selecting the active structure type exits, otherwise it enters.
    @client
]=]

local TogglePlacementModeCommand = {}
TogglePlacementModeCommand.__index = TogglePlacementModeCommand

--[=[
    Creates a new toggle-placement command.
    @within TogglePlacementModeCommand
    @param enterPlacementModeCommand any -- Command used to enter placement mode.
    @param exitPlacementModeCommand any -- Command used to exit placement mode.
    @return TogglePlacementModeCommand -- The command instance.
]=]
function TogglePlacementModeCommand.new(enterPlacementModeCommand: any, exitPlacementModeCommand: any)
	local self = setmetatable({}, TogglePlacementModeCommand)
	self._enterPlacementModeCommand = enterPlacementModeCommand
	self._exitPlacementModeCommand = exitPlacementModeCommand
	return self
end

--[=[
    Toggles placement mode for the requested structure type.
    @within TogglePlacementModeCommand
    @param state any -- Placement controller session state.
    @param deps any -- Controller dependencies and runtime adapters.
    @param structureType string -- The structure type to toggle.
]=]
function TogglePlacementModeCommand:Execute(state: any, deps: any, structureType: string)
	-- Confirmation requests own the session until they complete.
	if state._confirming then
		return
	end

	-- Toggling the active structure type closes the current session instead of reopening it.
	if state._state == "Active" and state._structureType == structureType then
		self._exitPlacementModeCommand:Execute(state, deps)
		return
	end

	-- Any other structure type request should open a fresh placement session.
	self._enterPlacementModeCommand:Execute(state, deps, structureType)
end

return TogglePlacementModeCommand
