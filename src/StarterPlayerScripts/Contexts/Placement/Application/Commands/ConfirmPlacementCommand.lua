--!strict

local ConfirmPlacementCommand = {}
ConfirmPlacementCommand.__index = ConfirmPlacementCommand

function ConfirmPlacementCommand.new(exitPlacementModeCommand: any)
	local self = setmetatable({}, ConfirmPlacementCommand)
	self._exitPlacementModeCommand = exitPlacementModeCommand
	return self
end

function ConfirmPlacementCommand:Execute(state: any, deps: any)
	if state._confirming or state._hoveredCoord == nil or state._isHoveredValid == false or state._structureType == nil then
		return
	end

	state._confirming = true
	local sessionId = state._sessionId

	local request = {
		coord_row = state._hoveredCoord.row,
		coord_col = state._hoveredCoord.col,
		structureType = state._structureType,
	}

	local ok, response = pcall(function()
		return deps.placementRemoteClient.PlaceStructure.Invoke(request)
	end)

	state._confirming = false

	if not ok then
		return
	end

	if sessionId ~= state._sessionId or state._state ~= "Active" then
		return
	end

	if response.success then
		self._exitPlacementModeCommand:Execute(state, deps)
	end
end

return ConfirmPlacementCommand
