--!strict

local BuildUnitSelectionState = require(script.Parent.Parent.BuildUnitSelectionState)

local AssignUnitControlGroupCommand = {}
AssignUnitControlGroupCommand.__index = AssignUnitControlGroupCommand

function AssignUnitControlGroupCommand.new()
	local self = setmetatable({}, AssignUnitControlGroupCommand)
	return self
end

function AssignUnitControlGroupCommand:Execute(deps: any, slot: number)
	local currentState = deps.selectionAtom()
	local nextControlGroupsBySlot = {}

	for existingSlot, unitGuids in pairs(currentState.ControlGroupsBySlot) do
		nextControlGroupsBySlot[existingSlot] = table.clone(unitGuids)
	end

	if currentState.SelectionCount > 0 then
		nextControlGroupsBySlot[slot] = table.clone(currentState.SelectedUnitGuids)
	else
		nextControlGroupsBySlot[slot] = nil
	end

	deps.selectionAtom(BuildUnitSelectionState({
		Records = deps.buildSelectedUnitRecordsQuery:Execute(currentState),
		ControlGroupsBySlot = nextControlGroupsBySlot,
		PreferredPrimaryUnitGuid = currentState.PrimarySelectedUnitGuid,
		IsMarqueeActive = currentState.IsMarqueeActive,
		MarqueeRect = currentState.MarqueeRect,
		PreviewUnitGuids = currentState.PreviewUnitGuids,
	}))
end

return AssignUnitControlGroupCommand
