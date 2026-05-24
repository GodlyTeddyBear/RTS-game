--!strict

local BuildUnitSelectionState = require(script.Parent.Parent.BuildUnitSelectionState)

local RecallUnitControlGroupCommand = {}
RecallUnitControlGroupCommand.__index = RecallUnitControlGroupCommand

function RecallUnitControlGroupCommand.new()
	local self = setmetatable({}, RecallUnitControlGroupCommand)
	return self
end

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
