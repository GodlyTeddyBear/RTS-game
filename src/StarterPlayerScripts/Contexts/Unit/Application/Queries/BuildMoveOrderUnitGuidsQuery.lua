--!strict

--[=[
    @class BuildMoveOrderUnitGuidsQuery
    Filters the current selection down to unit GUIDs that still have a live root for movement.

    @client
]=]

local UnitSelectionTypes = require(game:GetService("ReplicatedStorage").Contexts.Unit.Types.UnitSelectionTypes)

type TUnitSelectionState = UnitSelectionTypes.TUnitSelectionState

local BuildMoveOrderUnitGuidsQuery = {}
BuildMoveOrderUnitGuidsQuery.__index = BuildMoveOrderUnitGuidsQuery

-- Creates a query that extracts only the moveable units from the current selection.
function BuildMoveOrderUnitGuidsQuery.new()
	local self = setmetatable({}, BuildMoveOrderUnitGuidsQuery)
	return self
end

-- Skips detached roots so move-order requests only include units that are still present in the world.
function BuildMoveOrderUnitGuidsQuery:Execute(selectionState: TUnitSelectionState): { string }
	local moveOrderUnitGuids = {}

	for _, unitGuid in ipairs(selectionState.SelectedUnitGuids) do
		local root = selectionState.SelectedRootsByGuid[unitGuid]
		if root == nil or root.Parent == nil then
			continue
		end

		moveOrderUnitGuids[#moveOrderUnitGuids + 1] = unitGuid
	end

	return moveOrderUnitGuids
end

return BuildMoveOrderUnitGuidsQuery
