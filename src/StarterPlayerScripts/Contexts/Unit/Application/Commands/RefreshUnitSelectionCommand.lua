--!strict

local UnitSelectionTypes = require(game:GetService("ReplicatedStorage").Contexts.Unit.Types.UnitSelectionTypes)
local BuildUnitSelectionState = require(script.Parent.Parent.BuildUnitSelectionState)

type TSelectableUnitRecord = UnitSelectionTypes.TSelectableUnitRecord

local function _ApplyRecords(deps: any, records: { TSelectableUnitRecord })
	local currentState = deps.selectionAtom()
	deps.runtimeService:ApplySelectionRecords(records)
	deps.selectionAtom(BuildUnitSelectionState({
		Records = records,
		ControlGroupsBySlot = currentState.ControlGroupsBySlot,
		PreferredPrimaryUnitGuid = currentState.PrimarySelectedUnitGuid,
	}))
end

local RefreshUnitSelectionCommand = {}
RefreshUnitSelectionCommand.__index = RefreshUnitSelectionCommand

function RefreshUnitSelectionCommand.new()
	local self = setmetatable({}, RefreshUnitSelectionCommand)
	return self
end

function RefreshUnitSelectionCommand:Execute(deps: any, selectionSnapshot: any?)
	local records = {}
	if selectionSnapshot ~= nil and selectionSnapshot.Entries ~= nil then
		for _, entry in ipairs(selectionSnapshot.Entries) do
			records[#records + 1] = entry.Target
		end
	end

	local nextRecords = deps.resolveOwnedUnitSelectionQuery:ExecuteMany(records)
	_ApplyRecords(deps, nextRecords)
end

return RefreshUnitSelectionCommand
