--!strict

--[=[
    @class UpdateMarqueePreviewStateCommand
    Updates marquee preview state in the unit selection atom and mirrors the same snapshot into the overlay service.

    Owns marquee-only state transitions; does not own selection resolution or overlay construction.
    @client
]=]

local UnitSelectionTypes = require(game:GetService("ReplicatedStorage").Contexts.Unit.Types.UnitSelectionTypes)
local BuildUnitSelectionState = require(script.Parent.Parent.BuildUnitSelectionState)

type TMarqueeRect = UnitSelectionTypes.TMarqueeRect
type TUnitSelectionState = UnitSelectionTypes.TUnitSelectionState

local EMPTY_GUIDS = table.freeze({})

-- Normalizes the marquee snapshot into the frozen rectangle shape stored in the selection atom.
local function _BuildMarqueeRect(snapshot: any): TMarqueeRect?
	if snapshot == nil then
		return nil
	end

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

-- Creates a new command instance for the unit selection controller.
function UpdateMarqueePreviewStateCommand.new()
	local self = setmetatable({}, UpdateMarqueePreviewStateCommand)
	return self
end

-- Recomputes the marquee preview records, updates the overlay, and writes the next immutable selection state.
function UpdateMarqueePreviewStateCommand:Execute(deps: any, snapshot: any?)
	-- Preserve the current selection slices and recompute only the marquee-specific fields.
	local currentState = deps.selectionAtom()
	local previewRecords = deps.resolveOwnedUnitSelectionQuery:ExecuteMany(
		if snapshot ~= nil then snapshot.PreviewTargets else nil
	)
	local previewUnitGuids = table.create(#previewRecords)

	-- Convert resolved records into the compact GUID list stored in selection state.
	for _, record in ipairs(previewRecords) do
		previewUnitGuids[#previewUnitGuids + 1] = record.UnitGuid
	end

	-- Freeze the marquee rect and toggle the overlay from the same snapshot so UI and state cannot drift.
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
