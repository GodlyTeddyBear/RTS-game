--!strict

local UnitSelectionTypes = require(game:GetService("ReplicatedStorage").Contexts.UnitSelection.Types.UnitSelectionTypes)
local BuildUnitSelectionState = require(script.Parent.Parent.BuildUnitSelectionState)

type TSelectableUnitRecord = UnitSelectionTypes.TSelectableUnitRecord

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

function CommitSingleUnitSelectionCommand.new()
	local self = setmetatable({}, CommitSingleUnitSelectionCommand)
	return self
end

function CommitSingleUnitSelectionCommand:Execute(deps: any, resolvedTarget: any, _isShiftModifierActive: boolean)
	local record = deps.resolveOwnedUnitSelectionQuery:Execute(resolvedTarget)
	if record == nil then
		return
	end

	local currentState = deps.selectionAtom()
	local nextRecords = table.create(currentState.SelectionCount + 1)

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

	deps.runtimeService:ApplySelectionRecords(nextRecords)
	deps.marqueeOverlayService:Hide()
	deps.selectionAtom(BuildUnitSelectionState({
		Records = nextRecords,
		ControlGroupsBySlot = currentState.ControlGroupsBySlot,
		PreferredPrimaryUnitGuid = currentState.PrimarySelectedUnitGuid,
	}))
end

return CommitSingleUnitSelectionCommand
