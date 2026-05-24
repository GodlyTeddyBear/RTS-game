--!strict

local UnitSelectionTypes = require(game:GetService("ReplicatedStorage").Contexts.Unit.Types.UnitSelectionTypes)

type TUnitSelectionState = UnitSelectionTypes.TUnitSelectionState

local MOVABLE_UNIT_ROLES = table.freeze({
	Builder = true,
})

local BuildMoveOrderUnitGuidsQuery = {}
BuildMoveOrderUnitGuidsQuery.__index = BuildMoveOrderUnitGuidsQuery

function BuildMoveOrderUnitGuidsQuery.new()
	local self = setmetatable({}, BuildMoveOrderUnitGuidsQuery)
	return self
end

function BuildMoveOrderUnitGuidsQuery:Execute(selectionState: TUnitSelectionState): { string }
	local moveOrderUnitGuids = {}

	for _, unitGuid in ipairs(selectionState.SelectedUnitGuids) do
		local root = selectionState.SelectedRootsByGuid[unitGuid]
		if root == nil or root.Parent == nil then
			continue
		end

		local unitRole = root:GetAttribute("UnitRole")
		if type(unitRole) == "string" and MOVABLE_UNIT_ROLES[unitRole] == true then
			moveOrderUnitGuids[#moveOrderUnitGuids + 1] = unitGuid
		end
	end

	return moveOrderUnitGuids
end

return BuildMoveOrderUnitGuidsQuery
