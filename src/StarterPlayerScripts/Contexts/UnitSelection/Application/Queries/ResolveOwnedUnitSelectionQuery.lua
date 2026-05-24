--!strict

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SelectionPlus = require(ReplicatedStorage.Utilities.SelectionPlus)
local UnitSelectionTypes = require(ReplicatedStorage.Contexts.UnitSelection.Types.UnitSelectionTypes)

type TSelectableUnitRecord = UnitSelectionTypes.TSelectableUnitRecord

local ResolveOwnedUnitSelectionQuery = {}
ResolveOwnedUnitSelectionQuery.__index = ResolveOwnedUnitSelectionQuery

local function _BuildResolvedTargetFromRoot(root: Instance): SelectionPlus.TResolvedSelectionTarget?
	if root:IsA("Model") then
		return {
			Root = root,
			Adornee = root,
			WorldPosition = root:GetPivot().Position,
		}
	end

	if root:IsA("BasePart") then
		return {
			Root = root,
			Adornee = root,
			WorldPosition = root.Position,
		}
	end

	return nil
end

local function _ResolveResolvedTarget(candidate: any): SelectionPlus.TResolvedSelectionTarget?
	if typeof(candidate) == "Instance" then
		return _BuildResolvedTargetFromRoot(candidate)
	end

	if type(candidate) ~= "table" then
		return nil
	end

	if candidate.Root ~= nil and candidate.Adornee ~= nil and candidate.WorldPosition ~= nil then
		return candidate :: SelectionPlus.TResolvedSelectionTarget
	end

	if candidate.Target ~= nil then
		return _ResolveResolvedTarget(candidate.Target)
	end

	return nil
end

local function _IsOwnedUnitRoot(localOwnerId: string, root: Instance): boolean
	if root.Parent == nil or not root:IsDescendantOf(Workspace) then
		return false
	end

	local unitGuid = root:GetAttribute("UnitGuid")
	local ownerKind = root:GetAttribute("OwnerKind")
	local ownerId = root:GetAttribute("OwnerId")

	return type(unitGuid) == "string"
		and unitGuid ~= ""
		and ownerKind == "Player"
		and ownerId == localOwnerId
end

local function _SortRecords(records: { TSelectableUnitRecord })
	table.sort(records, function(left, right)
		return left.UnitGuid < right.UnitGuid
	end)
end

function ResolveOwnedUnitSelectionQuery.new()
	local self = setmetatable({}, ResolveOwnedUnitSelectionQuery)
	local localPlayer = Players.LocalPlayer
	self._localOwnerId = if localPlayer ~= nil then tostring(localPlayer.UserId) else ""
	return self
end

function ResolveOwnedUnitSelectionQuery:Execute(candidate: any): TSelectableUnitRecord?
	local resolvedTarget = _ResolveResolvedTarget(candidate)
	if resolvedTarget == nil then
		return nil
	end

	local root = resolvedTarget.Root
	if not _IsOwnedUnitRoot(self._localOwnerId, root) then
		return nil
	end

	local unitGuid = root:GetAttribute("UnitGuid")
	if type(unitGuid) ~= "string" or unitGuid == "" then
		return nil
	end

	return table.freeze({
		UnitGuid = unitGuid,
		Root = root,
		Target = resolvedTarget,
	})
end

function ResolveOwnedUnitSelectionQuery:ExecuteMany(candidates: { any }?): { TSelectableUnitRecord }
	if candidates == nil then
		return table.freeze({})
	end

	local records = {}
	local seenUnitGuids = {}

	for _, candidate in ipairs(candidates) do
		local record = self:Execute(candidate)
		if record ~= nil and seenUnitGuids[record.UnitGuid] ~= true then
			seenUnitGuids[record.UnitGuid] = true
			records[#records + 1] = record
		end
	end

	_SortRecords(records)
	return table.freeze(records)
end

return ResolveOwnedUnitSelectionQuery
