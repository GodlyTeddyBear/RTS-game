--!strict

local UnitSelectionTypes = require(game:GetService("ReplicatedStorage").Contexts.UnitSelection.Types.UnitSelectionTypes)

type TSelectableUnitRecord = UnitSelectionTypes.TSelectableUnitRecord

local BuildSelectedUnitRecordsQuery = {}
BuildSelectedUnitRecordsQuery.__index = BuildSelectedUnitRecordsQuery

function BuildSelectedUnitRecordsQuery.new()
	local self = setmetatable({}, BuildSelectedUnitRecordsQuery)
	return self
end

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
