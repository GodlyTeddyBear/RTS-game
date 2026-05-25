--!strict

--[=[
    @class RefreshUnitSelectionCommand
    Rebuilds selection state after the runtime invalidates the current snapshot.

    Owns the refresh path only; does not own selection resolution or runtime invalidation detection.
    @client
]=]

local UnitSelectionTypes = require(game:GetService("ReplicatedStorage").Contexts.Unit.Types.UnitSelectionTypes)
local BuildUnitSelectionState = require(script.Parent.Parent.BuildUnitSelectionState)

type TSelectableUnitRecord = UnitSelectionTypes.TSelectableUnitRecord

-- Rebuilds the selected-record list through the owned-selection query so invalidated entries are dropped in one pass.
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

-- Creates a command that can rebuild the current selection from a stale runtime snapshot.
function RefreshUnitSelectionCommand.new()
	local self = setmetatable({}, RefreshUnitSelectionCommand)
	return self
end

-- Extracts stale targets from the invalidated snapshot, resolves the surviving records, and reapplies them.
function RefreshUnitSelectionCommand:Execute(deps: any, selectionSnapshot: any?)
	-- Pull the old targets out of the invalidated snapshot when one exists.
	local records = {}
	if selectionSnapshot ~= nil and selectionSnapshot.Entries ~= nil then
		for _, entry in ipairs(selectionSnapshot.Entries) do
			records[#records + 1] = entry.Target
		end
	end

	-- Resolve only the records that still belong to the local player and rebuild the atom from them.
	local nextRecords = deps.resolveOwnedUnitSelectionQuery:ExecuteMany(records)
	_ApplyRecords(deps, nextRecords)
end

return RefreshUnitSelectionCommand
