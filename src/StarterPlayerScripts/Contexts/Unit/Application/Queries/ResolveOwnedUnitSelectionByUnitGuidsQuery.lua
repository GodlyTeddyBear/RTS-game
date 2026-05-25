--!strict

--[=[
    @class ResolveOwnedUnitSelectionByUnitGuidsQuery
    Resolves owned unit records from a list of unit GUIDs by scanning the tagged unit instances.

    @client
]=]

local CollectionService = game:GetService("CollectionService")

local UnitSelectionTypes = require(game:GetService("ReplicatedStorage").Contexts.Unit.Types.UnitSelectionTypes)

type TSelectableUnitRecord = UnitSelectionTypes.TSelectableUnitRecord

local UNIT_TAG = "CombatUnit"

local ResolveOwnedUnitSelectionByUnitGuidsQuery = {}
ResolveOwnedUnitSelectionByUnitGuidsQuery.__index = ResolveOwnedUnitSelectionByUnitGuidsQuery

-- Creates a query that reuses the base owned-selection resolver for GUID lookups.
function ResolveOwnedUnitSelectionByUnitGuidsQuery.new(resolveOwnedUnitSelectionQuery: any)
	local self = setmetatable({}, ResolveOwnedUnitSelectionByUnitGuidsQuery)
	self._resolveOwnedUnitSelectionQuery = resolveOwnedUnitSelectionQuery
	return self
end

-- Resolves only the tagged units that match the requested GUIDs and removes duplicates from the result.
function ResolveOwnedUnitSelectionByUnitGuidsQuery:Execute(unitGuids: { string }?): { TSelectableUnitRecord }
	if unitGuids == nil or #unitGuids == 0 then
		return table.freeze({})
	end

	local rootsByUnitGuid = {}
	-- Build a root index from the live tagged units before filtering to the requested GUIDs.
	for _, taggedInstance in ipairs(CollectionService:GetTagged(UNIT_TAG)) do
		local record = self._resolveOwnedUnitSelectionQuery:Execute(taggedInstance)
		if record ~= nil then
			rootsByUnitGuid[record.UnitGuid] = record.Root
		end
	end

	local records = table.create(#unitGuids)
	local seenUnitGuids = {}

	for _, unitGuid in ipairs(unitGuids) do
		if seenUnitGuids[unitGuid] == true then
			continue
		end

		local root = rootsByUnitGuid[unitGuid]
		if root == nil then
			continue
		end

		local record = self._resolveOwnedUnitSelectionQuery:Execute(root)
		if record ~= nil then
			seenUnitGuids[unitGuid] = true
			records[#records + 1] = record
		end
	end

	return records
end

return ResolveOwnedUnitSelectionByUnitGuidsQuery
