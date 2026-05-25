--!strict

--[=[
    @class RecallUnitControlGroupCommand
    Restores a saved control-group selection from the atom and reapplies the visible runtime selection set.

    @client
]=]

local BuildUnitSelectionState = require(script.Parent.Parent.BuildUnitSelectionState)

local RecallUnitControlGroupCommand = {}
RecallUnitControlGroupCommand.__index = RecallUnitControlGroupCommand

-- Creates a command used by the selection controller for hotkey recall.
function RecallUnitControlGroupCommand.new()
	local self = setmetatable({}, RecallUnitControlGroupCommand)
	return self
end

-- Rebuilds selection from the requested hotkey slot and clears any marquee overlay left from the previous gesture.
function RecallUnitControlGroupCommand:Execute(deps: any, slot: number)
	local currentState = deps.selectionAtom()
	local unitGuids = currentState.ControlGroupsBySlot[slot]
	local nextRecords = deps.resolveOwnedUnitSelectionByUnitGuidsQuery:Execute(unitGuids)

	deps.runtimeService:ApplySelectionRecords(nextRecords)
	deps.marqueeOverlayService:Hide()
	deps.selectionAtom(BuildUnitSelectionState({
		Records = nextRecords,
		ControlGroupsBySlot = currentState.ControlGroupsBySlot,
	}))
end

return RecallUnitControlGroupCommand
