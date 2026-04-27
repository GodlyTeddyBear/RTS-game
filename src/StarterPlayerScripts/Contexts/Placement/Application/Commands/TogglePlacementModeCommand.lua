--!strict

local TogglePlacementModeCommand = {}
TogglePlacementModeCommand.__index = TogglePlacementModeCommand

function TogglePlacementModeCommand.new(enterPlacementModeCommand: any, exitPlacementModeCommand: any)
	local self = setmetatable({}, TogglePlacementModeCommand)
	self._enterPlacementModeCommand = enterPlacementModeCommand
	self._exitPlacementModeCommand = exitPlacementModeCommand
	return self
end

function TogglePlacementModeCommand:Execute(state: any, deps: any, structureType: string)
	if state._confirming then
		return
	end

	if state._state == "Active" and state._structureType == structureType then
		self._exitPlacementModeCommand:Execute(state, deps)
		return
	end

	self._enterPlacementModeCommand:Execute(state, deps, structureType)
end

return TogglePlacementModeCommand
