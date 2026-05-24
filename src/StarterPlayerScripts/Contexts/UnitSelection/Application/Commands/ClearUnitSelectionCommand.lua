--!strict

local UnitSelectionTypes = require(game:GetService("ReplicatedStorage").Contexts.UnitSelection.Types.UnitSelectionTypes)
local BuildUnitSelectionState = require(script.Parent.Parent.BuildUnitSelectionState)

type TUnitSelectionState = UnitSelectionTypes.TUnitSelectionState

local ClearUnitSelectionCommand = {}
ClearUnitSelectionCommand.__index = ClearUnitSelectionCommand

function ClearUnitSelectionCommand.new()
	local self = setmetatable({}, ClearUnitSelectionCommand)
	return self
end

function ClearUnitSelectionCommand:Execute(deps: any)
	local currentState: TUnitSelectionState = deps.selectionAtom()
	deps.runtimeService:ClearSelection()
	deps.marqueeOverlayService:Hide()
	deps.selectionAtom(BuildUnitSelectionState({
		Records = {},
		ControlGroupsBySlot = currentState.ControlGroupsBySlot,
	}))
end

return ClearUnitSelectionCommand
