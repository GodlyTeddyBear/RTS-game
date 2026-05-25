--!strict

--[=[
    @class CommitSingleUnitSelectionCommand
    Commits a single unit selection and keeps shift-additive selection behavior consistent.

    @client
]=]

local UnitSelectionTypes = require(game:GetService("ReplicatedStorage").Contexts.Unit.Types.UnitSelectionTypes)
local BuildUnitSelectionState = require(script.Parent.Parent.BuildUnitSelectionState)

type TSelectableUnitRecord = UnitSelectionTypes.TSelectableUnitRecord

-- Finds an existing record so shift-click can replace the current primary target without duplicates.
local function _FindRecordIndex(records: { TSelectableUnitRecord }, unitGuid: string): number?
	for index, record in ipairs(records) do
		if record.UnitGuid == unitGuid then
			return index
		end
	end

	return nil
end

local CommitSingleUnitSelectionCommand = {}
CommitSingleUnitSelectionCommand.__index = CommitSingleUnitSelectionCommand

-- Creates a command that can commit the result of a single selection click.
function CommitSingleUnitSelectionCommand.new()
	local self = setmetatable({}, CommitSingleUnitSelectionCommand)
	return self
end

-- Resolves a clicked unit, merges it into the current selection when needed, and writes the new atom state.
function CommitSingleUnitSelectionCommand:Execute(deps: any, resolvedTarget: any, isShiftModifierActive: boolean)
	local record = deps.resolveOwnedUnitSelectionQuery:Execute(resolvedTarget)
	if record == nil then
		return
	end

	local currentState = deps.selectionAtom()
	local nextRecords = if isShiftModifierActive then table.create(currentState.SelectionCount + 1) else { record }

	if isShiftModifierActive then
		-- Rebuild the current selection so shift-click can toggle one unit without dropping the rest.
		for _, selectedUnitGuid in ipairs(currentState.SelectedUnitGuids) do
			local selectedRoot = currentState.SelectedRootsByGuid[selectedUnitGuid]
			if selectedRoot ~= nil and selectedRoot.Parent ~= nil then
				nextRecords[#nextRecords + 1] = table.freeze({
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

		local existingRecordIndex = _FindRecordIndex(nextRecords, record.UnitGuid)
		if existingRecordIndex ~= nil then
			table.remove(nextRecords, existingRecordIndex)
		else
			nextRecords[#nextRecords + 1] = record
		end
	end

	deps.runtimeService:ApplySelectionRecords(nextRecords)
	deps.marqueeOverlayService:Hide()
	deps.selectionAtom(BuildUnitSelectionState({
		Records = nextRecords,
		ControlGroupsBySlot = currentState.ControlGroupsBySlot,
		PreferredPrimaryUnitGuid = if isShiftModifierActive then currentState.PrimarySelectedUnitGuid else record.UnitGuid,
	}))
end

return CommitSingleUnitSelectionCommand
