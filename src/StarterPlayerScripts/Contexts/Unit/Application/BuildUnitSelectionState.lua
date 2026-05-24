--!strict

local UnitSelectionTypes = require(game:GetService("ReplicatedStorage").Contexts.Unit.Types.UnitSelectionTypes)

type TSelectableUnitRecord = UnitSelectionTypes.TSelectableUnitRecord
type TControlGroupsBySlot = UnitSelectionTypes.TControlGroupsBySlot
type TMarqueeRect = UnitSelectionTypes.TMarqueeRect
type TUnitSelectionState = UnitSelectionTypes.TUnitSelectionState

local EMPTY_GUIDS = table.freeze({})
local EMPTY_ROOTS_BY_GUID = table.freeze({})
local EMPTY_CONTROL_GROUPS = table.freeze({})

type TBuildUnitSelectionStateOptions = {
	Records: { TSelectableUnitRecord },
	ControlGroupsBySlot: TControlGroupsBySlot?,
	PreferredPrimaryUnitGuid: string?,
	IsMarqueeActive: boolean?,
	MarqueeRect: TMarqueeRect?,
	PreviewUnitGuids: { string }?,
}

local function _ContainsGuid(unitGuids: { string }, unitGuid: string): boolean
	for _, guid in ipairs(unitGuids) do
		if guid == unitGuid then
			return true
		end
	end

	return false
end

local function _FreezeControlGroupsBySlot(controlGroupsBySlot: TControlGroupsBySlot?): TControlGroupsBySlot
	if controlGroupsBySlot == nil or next(controlGroupsBySlot) == nil then
		return EMPTY_CONTROL_GROUPS
	end

	local nextControlGroupsBySlot = {}
	for slot, unitGuids in pairs(controlGroupsBySlot) do
		local nextUnitGuids = table.clone(unitGuids)
		nextControlGroupsBySlot[slot] = table.freeze(nextUnitGuids)
	end

	return table.freeze(nextControlGroupsBySlot)
end

local function BuildUnitSelectionState(options: TBuildUnitSelectionStateOptions): TUnitSelectionState
	local selectedUnitGuids = table.create(#options.Records)
	local selectedRootsByGuid = {}

	for _, record in ipairs(options.Records) do
		selectedUnitGuids[#selectedUnitGuids + 1] = record.UnitGuid
		selectedRootsByGuid[record.UnitGuid] = record.Root
	end

	local preferredPrimaryUnitGuid = options.PreferredPrimaryUnitGuid
	local nextPrimaryUnitGuid = nil
	if preferredPrimaryUnitGuid ~= nil and _ContainsGuid(selectedUnitGuids, preferredPrimaryUnitGuid) then
		nextPrimaryUnitGuid = preferredPrimaryUnitGuid
	elseif #selectedUnitGuids > 0 then
		nextPrimaryUnitGuid = selectedUnitGuids[1]
	end

	local previewUnitGuids = options.PreviewUnitGuids
	local nextPreviewUnitGuids = if previewUnitGuids ~= nil and #previewUnitGuids > 0 then table.freeze(table.clone(previewUnitGuids)) else EMPTY_GUIDS

	return table.freeze({
		SelectedUnitGuids = if #selectedUnitGuids > 0 then table.freeze(selectedUnitGuids) else EMPTY_GUIDS,
		SelectedRootsByGuid = if next(selectedRootsByGuid) ~= nil then table.freeze(selectedRootsByGuid) else EMPTY_ROOTS_BY_GUID,
		PrimarySelectedUnitGuid = nextPrimaryUnitGuid,
		SelectionCount = #selectedUnitGuids,
		IsMarqueeActive = options.IsMarqueeActive == true,
		MarqueeRect = options.MarqueeRect,
		PreviewUnitGuids = nextPreviewUnitGuids,
		ControlGroupsBySlot = _FreezeControlGroupsBySlot(options.ControlGroupsBySlot),
	})
end

return BuildUnitSelectionState
