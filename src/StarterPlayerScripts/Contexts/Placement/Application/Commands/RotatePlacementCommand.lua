--!strict

local RotatePlacementCommand = {}
RotatePlacementCommand.__index = RotatePlacementCommand

function RotatePlacementCommand.new(refreshValidTilesCommand: any)
	local self = setmetatable({}, RotatePlacementCommand)
	self._refreshValidTilesCommand = refreshValidTilesCommand
	return self
end

function RotatePlacementCommand:Execute(state: any, placementAtom: any)
	if state._state ~= "Active" or state._structureType == nil then
		return
	end

	state._rotationQuarterTurns = (state._rotationQuarterTurns + 1) % 4
	self._refreshValidTilesCommand:Execute(state, placementAtom)
end

return RotatePlacementCommand
