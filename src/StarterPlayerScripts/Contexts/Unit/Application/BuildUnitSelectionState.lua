--!strict

--[=[
    @class BuildUnitSelectionState
    Builds the immutable unit selection snapshot consumed by the client unit-selection controller.

    Owns normalization of selected records, control groups, marquee preview state, and primary selection fallback.
    @client
]=]

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

-- Checks whether a preferred primary unit still exists in the current selection set.
local function _ContainsGuid(unitGuids: { string }, unitGuid: string): boolean
	for _, guid in ipairs(unitGuids) do
		if guid == unitGuid then
			return true
		end
	end

	return false
end

-- Freezes control-group tables defensively so the selection atom cannot be mutated from the outside.
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

--[=[
    Builds the immutable unit selection snapshot consumed by the client controller and runtime services.

    @within BuildUnitSelectionState
    @param options TBuildUnitSelectionStateOptions -- Selection records and preserved state slices.
    @return TUnitSelectionState -- Frozen selection snapshot.
]=]
local function BuildUnitSelectionState(options: TBuildUnitSelectionStateOptions): TUnitSelectionState
	-- Collect the selected units and the live roots that still remain in the world.
	local selectedUnitGuids = table.create(#options.Records)
	local selectedRootsByGuid = {}

	for _, record in ipairs(options.Records) do
		selectedUnitGuids[#selectedUnitGuids + 1] = record.UnitGuid
		selectedRootsByGuid[record.UnitGuid] = record.Root
	end

	-- Keep the preferred primary selection only if it still belongs to the current records.
	local preferredPrimaryUnitGuid = options.PreferredPrimaryUnitGuid
	local nextPrimaryUnitGuid = nil
	if preferredPrimaryUnitGuid ~= nil and _ContainsGuid(selectedUnitGuids, preferredPrimaryUnitGuid) then
		nextPrimaryUnitGuid = preferredPrimaryUnitGuid
	elseif #selectedUnitGuids > 0 then
		nextPrimaryUnitGuid = selectedUnitGuids[1]
	end

	local previewUnitGuids = options.PreviewUnitGuids
	local nextPreviewUnitGuids = if previewUnitGuids ~= nil and #previewUnitGuids > 0 then table.freeze(table.clone(previewUnitGuids)) else EMPTY_GUIDS

	-- Freeze each slice so downstream consumers read a stable selection snapshot.
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
