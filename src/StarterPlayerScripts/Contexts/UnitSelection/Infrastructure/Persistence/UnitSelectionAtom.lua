--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Charm = require(ReplicatedStorage.Packages.Charm)
local UnitSelectionTypes = require(ReplicatedStorage.Contexts.UnitSelection.Types.UnitSelectionTypes)

type TUnitSelectionState = UnitSelectionTypes.TUnitSelectionState

local EMPTY_GUIDS = table.freeze({})
local EMPTY_ROOTS_BY_GUID = table.freeze({})
local EMPTY_CONTROL_GROUPS = table.freeze({})

local DEFAULT_STATE: TUnitSelectionState = table.freeze({
	SelectedUnitGuids = EMPTY_GUIDS,
	SelectedRootsByGuid = EMPTY_ROOTS_BY_GUID,
	PrimarySelectedUnitGuid = nil,
	SelectionCount = 0,
	IsMarqueeActive = false,
	MarqueeRect = nil,
	PreviewUnitGuids = EMPTY_GUIDS,
	ControlGroupsBySlot = EMPTY_CONTROL_GROUPS,
})

local unitSelectionAtom = Charm.atom(DEFAULT_STATE)

local function GetUnitSelectionAtom()
	return unitSelectionAtom
end

return GetUnitSelectionAtom
