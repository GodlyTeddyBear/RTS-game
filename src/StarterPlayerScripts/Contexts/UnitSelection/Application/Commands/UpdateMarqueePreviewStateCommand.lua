--!strict

local UnitSelectionTypes = require(game:GetService("ReplicatedStorage").Contexts.UnitSelection.Types.UnitSelectionTypes)

type TMarqueeRect = UnitSelectionTypes.TMarqueeRect
type TUnitSelectionState = UnitSelectionTypes.TUnitSelectionState

local EMPTY_GUIDS = table.freeze({})

local function _BuildMarqueeRect(snapshot: any): TMarqueeRect?
	local normalizedScreenRect = snapshot.NormalizedScreenRect
	if normalizedScreenRect == nil then
		return nil
	end

	return table.freeze({
		Min = normalizedScreenRect.Min,
		Max = normalizedScreenRect.Max,
		Size = normalizedScreenRect.Size,
	})
end

local UpdateMarqueePreviewStateCommand = {}
UpdateMarqueePreviewStateCommand.__index = UpdateMarqueePreviewStateCommand

function UpdateMarqueePreviewStateCommand.new()
	local self = setmetatable({}, UpdateMarqueePreviewStateCommand)
	return self
end

function UpdateMarqueePreviewStateCommand:Execute(deps: any, snapshot: any?)
	local currentState = deps.selectionAtom()
	local previewRecords = deps.resolveOwnedUnitSelectionQuery:ExecuteMany(
		if snapshot ~= nil then snapshot.PreviewTargets else nil
	)
	local previewUnitGuids = table.create(#previewRecords)

	for _, record in ipairs(previewRecords) do
		previewUnitGuids[#previewUnitGuids + 1] = record.UnitGuid
	end

	local marqueeRect = _BuildMarqueeRect(snapshot)
	local nextState: TUnitSelectionState = table.freeze({
		SelectedUnitGuids = currentState.SelectedUnitGuids,
		SelectedRootsByGuid = currentState.SelectedRootsByGuid,
		PrimarySelectedUnitGuid = currentState.PrimarySelectedUnitGuid,
		SelectionCount = currentState.SelectionCount,
		IsMarqueeActive = snapshot ~= nil,
		MarqueeRect = marqueeRect,
		PreviewUnitGuids = if #previewUnitGuids > 0 then table.freeze(previewUnitGuids) else EMPTY_GUIDS,
		ControlGroupsBySlot = currentState.ControlGroupsBySlot,
	})

	if marqueeRect ~= nil then
		deps.marqueeOverlayService:Show(marqueeRect)
	else
		deps.marqueeOverlayService:Hide()
	end

	deps.selectionAtom(nextState)
end

return UpdateMarqueePreviewStateCommand
