--!strict

--[=[
    @class ClearUnitSelectionCommand
    Clears the current unit selection and preserves the existing control-group table.

    @client
]=]

local UnitSelectionTypes = require(game:GetService("ReplicatedStorage").Contexts.Unit.Types.UnitSelectionTypes)
local BuildUnitSelectionState = require(script.Parent.Parent.BuildUnitSelectionState)

type TUnitSelectionState = UnitSelectionTypes.TUnitSelectionState

local ClearUnitSelectionCommand = {}
ClearUnitSelectionCommand.__index = ClearUnitSelectionCommand

-- Creates a command that can clear the current selection state on demand.
function ClearUnitSelectionCommand.new()
	local self = setmetatable({}, ClearUnitSelectionCommand)
	return self
end

-- Clears the runtime selection, hides the overlay, and resets the atom to an empty selection snapshot.
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
