--!strict

--[=[
    @class UnitSelectionAtom
    Exposes the client selection atom used by the unit selection controller and runtime services.

    @client
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Charm = require(ReplicatedStorage.Packages.Charm)
local UnitSelectionTypes = require(ReplicatedStorage.Contexts.Unit.Types.UnitSelectionTypes)

type TUnitSelectionState = UnitSelectionTypes.TUnitSelectionState

local EMPTY_GUIDS = table.freeze({})
local EMPTY_ROOTS_BY_GUID = table.freeze({})
local EMPTY_CONTROL_GROUPS = table.freeze({})

-- Seeds the atom with a frozen empty snapshot so downstream readers always receive a stable structure.
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

-- Returns the shared atom accessor used by the client selection context.
local function GetUnitSelectionAtom()
	return unitSelectionAtom
end

return GetUnitSelectionAtom
