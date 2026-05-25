--!strict

--[=[
    @class BuildSelectedUnitRecordsQuery
    Rebuilds selection records from the current selection atom snapshot.

    @client
]=]

local UnitSelectionTypes = require(game:GetService("ReplicatedStorage").Contexts.Unit.Types.UnitSelectionTypes)

type TSelectableUnitRecord = UnitSelectionTypes.TSelectableUnitRecord

local BuildSelectedUnitRecordsQuery = {}
BuildSelectedUnitRecordsQuery.__index = BuildSelectedUnitRecordsQuery

-- Creates a query that turns the atom's selection slices back into live selection records.
function BuildSelectedUnitRecordsQuery.new()
	local self = setmetatable({}, BuildSelectedUnitRecordsQuery)
	return self
end

-- Rebuilds only the records whose roots still exist so downstream commands do not operate on stale instances.
function BuildSelectedUnitRecordsQuery:Execute(selectionState: any): { TSelectableUnitRecord }
	local records = table.create(selectionState.SelectionCount)

	for _, selectedUnitGuid in ipairs(selectionState.SelectedUnitGuids) do
		local selectedRoot = selectionState.SelectedRootsByGuid[selectedUnitGuid]
		if selectedRoot ~= nil and selectedRoot.Parent ~= nil then
			records[#records + 1] = table.freeze({
				UnitGuid = selectedUnitGuid,
				Root = selectedRoot,
				Target = {
					Root = selectedRoot,
					Adornee = selectedRoot,
					WorldPosition = selectedRoot:GetPivot().Position,
				},
			})
		end
	end

	return records
end

return BuildSelectedUnitRecordsQuery
