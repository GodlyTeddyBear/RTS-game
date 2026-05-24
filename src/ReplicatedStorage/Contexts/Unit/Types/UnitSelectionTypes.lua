--!strict

--[=[
	@class UnitSelectionTypes
	Defines shared client-side unit selection state and record types.
	@client
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SelectionPlus = require(ReplicatedStorage.Utilities.SelectionPlus)

local UnitSelectionTypes = {}

export type TMarqueeRect = {
	Min: Vector2,
	Max: Vector2,
	Size: Vector2,
}

export type TSelectableUnitRecord = {
	UnitGuid: string,
	Root: Instance,
	Target: SelectionPlus.TResolvedSelectionTarget,
}

export type TControlGroupsBySlot = {
	[number]: { string },
}

export type TUnitSelectionState = {
	SelectedUnitGuids: { string },
	SelectedRootsByGuid: { [string]: Instance },
	PrimarySelectedUnitGuid: string?,
	SelectionCount: number,
	IsMarqueeActive: boolean,
	MarqueeRect: TMarqueeRect?,
	PreviewUnitGuids: { string },
	ControlGroupsBySlot: TControlGroupsBySlot,
}

return table.freeze(UnitSelectionTypes)
