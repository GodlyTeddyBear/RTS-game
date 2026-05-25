--!strict

--[=[
    @class CommitMarqueeUnitSelectionCommand
    Commits a marquee selection preview into the atom and clears the marquee overlay.

    @client
]=]

local UnitSelectionTypes = require(game:GetService("ReplicatedStorage").Contexts.Unit.Types.UnitSelectionTypes)
local BuildUnitSelectionState = require(script.Parent.Parent.BuildUnitSelectionState)

type TSelectableUnitRecord = UnitSelectionTypes.TSelectableUnitRecord

-- Finds an existing record so shift-marquee can toggle overlaps instead of duplicating them.
local function _FindRecordIndex(records: { TSelectableUnitRecord }, unitGuid: string): number?
	for index, record in ipairs(records) do
		if record.UnitGuid == unitGuid then
			return index
		end
	end

	return nil
end

-- Rebuilds the current selection records so shift-marquee can preserve already-selected units.
local function _BuildCurrentSelectionRecords(currentState: any): { TSelectableUnitRecord }
	local records = table.create(currentState.SelectionCount)

	for _, selectedUnitGuid in ipairs(currentState.SelectedUnitGuids) do
		local selectedRoot = currentState.SelectedRootsByGuid[selectedUnitGuid]
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

local CommitMarqueeUnitSelectionCommand = {}
CommitMarqueeUnitSelectionCommand.__index = CommitMarqueeUnitSelectionCommand

-- Creates a command that can commit marquee previews from the runtime service.
function CommitMarqueeUnitSelectionCommand.new()
	local self = setmetatable({}, CommitMarqueeUnitSelectionCommand)
	return self
end

-- Resolves preview targets, applies shift-toggle semantics, and writes the committed selection state.
function CommitMarqueeUnitSelectionCommand:Execute(deps: any, previewTargets: { any }?, isShiftModifierActive: boolean)
	local currentState = deps.selectionAtom()
	local previewRecords = deps.resolveOwnedUnitSelectionQuery:ExecuteMany(previewTargets)
	local nextRecords = if isShiftModifierActive then _BuildCurrentSelectionRecords(currentState) else table.clone(previewRecords)

	if isShiftModifierActive then
		-- Toggle each previewed record against the existing selection so marquee shift-click behaves symmetrically.
		for _, previewRecord in ipairs(previewRecords) do
			local existingRecordIndex = _FindRecordIndex(nextRecords, previewRecord.UnitGuid)
			if existingRecordIndex ~= nil then
				table.remove(nextRecords, existingRecordIndex)
			else
				nextRecords[#nextRecords + 1] = previewRecord
			end
		end
	end

	deps.runtimeService:ApplySelectionRecords(nextRecords)
	deps.marqueeOverlayService:Hide()
	deps.selectionAtom(BuildUnitSelectionState({
		Records = nextRecords,
		ControlGroupsBySlot = currentState.ControlGroupsBySlot,
		PreferredPrimaryUnitGuid = currentState.PrimarySelectedUnitGuid,
	}))
end

return CommitMarqueeUnitSelectionCommand
