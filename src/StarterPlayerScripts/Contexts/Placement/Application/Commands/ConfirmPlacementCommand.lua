--!strict

--[=[
    @class ConfirmPlacementCommand
    Submits the current placement request and exits placement mode on success.

    The placement cursor controller uses this command to freeze the session, issue the
    remote placement request, and tear down the preview when the server accepts it.
    @client
]=]

local ConfirmPlacementCommand = {}
ConfirmPlacementCommand.__index = ConfirmPlacementCommand

--[=[
    Creates a new confirm-placement command.
    @within ConfirmPlacementCommand
    @param exitPlacementModeCommand any -- Command used to exit placement mode after success.
    @return ConfirmPlacementCommand -- The command instance.
]=]
function ConfirmPlacementCommand.new(exitPlacementModeCommand: any)
	local self = setmetatable({}, ConfirmPlacementCommand)
	self._exitPlacementModeCommand = exitPlacementModeCommand
	return self
end

--[=[
    Sends the placement request for the currently hovered tile.
    @within ConfirmPlacementCommand
    @param state any -- Placement controller session state.
    @param deps any -- Controller dependencies and runtime adapters.
]=]
function ConfirmPlacementCommand:Execute(state: any, deps: any)
	-- Confirm only when a valid hover target and structure type are available.
	if state._confirming or state._hoveredCoord == nil or state._isHoveredValid == false or state._structureType == nil then
		return
	end

	-- Freeze the session while the remote request is in flight.
	state._confirming = true
	local sessionId = state._sessionId

	-- Marshal the request payload from the current hover target.
	local request = {
		coord_row = state._hoveredCoord.row,
		coord_col = state._hoveredCoord.col,
		structureType = state._structureType,
	}

	-- Wrap the remote invocation so a network failure does not destabilize the session.
	local ok, response = pcall(function()
		return deps.placementRemoteClient.PlaceStructure.Invoke(request)
	end)

	state._confirming = false

	if not ok then
		return
	end

	-- Ignore late responses from stale sessions.
	if sessionId ~= state._sessionId or state._state ~= "Active" then
		return
	end

	-- Successful placement closes the session and clears the preview state.
	if response.success then
		self._exitPlacementModeCommand:Execute(state, deps)
	end
end

return ConfirmPlacementCommand
