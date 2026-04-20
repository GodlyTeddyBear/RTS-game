--!strict
local SlotViewModel = require(script.Parent.SlotViewModel)

--[=[
	@type TBuildingPickerOption
	@within BuildingPickerViewModel
	.BuildingType string -- The building type identifier
	.Cost { [string]: number } -- Currency cost to construct
	.MaxLevel number -- Maximum upgradeable level
	.IsLocked boolean -- Whether this building type is locked
	.IsAffordable boolean -- Whether the player can afford this option
	.CostText string -- Pre-formatted cost string (e.g. "100 Gold")
	.MaxLevelText string -- Pre-formatted max level string (e.g. "Max Lv.5")
]=]
export type TBuildingPickerOption = {
	BuildingType: string,
	Cost: { [string]: number },
	MaxLevel: number,
	IsLocked: boolean,
	IsAffordable: boolean,
	CostText: string,
	MaxLevelText: string,
}

--[=[
	@type TBuildingPickerViewData
	@within BuildingPickerViewModel
	.options { TBuildingPickerOption } -- Enriched building options for display
]=]
export type TBuildingPickerViewData = {
	options: { TBuildingPickerOption },
}

--[=[
	@class BuildingPickerViewModel
	Enriches raw SlotViewModel building options with affordability and pre-formatted display strings.
]=]
local BuildingPickerViewModel = {}

local function _formatCost(cost: { [string]: number }): string
	local parts: { string } = {}
	for currency, amount in cost do
		table.insert(parts, tostring(amount) .. " " .. currency)
	end
	return table.concat(parts, ", ")
end

--[=[
	Builds display-ready building picker options for a zone, enriched with gold affordability.
	@within BuildingPickerViewModel
	@param zoneName string -- The zone to get building options for
	@param unlockState any -- Current player unlock state
	@param gold number -- Current player gold balance
	@return TBuildingPickerViewData -- Immutable enriched option list
]=]
function BuildingPickerViewModel.fromZone(zoneName: string, unlockState: any, gold: number): TBuildingPickerViewData
	local rawOptions = SlotViewModel.buildBuildingOptions(zoneName, unlockState)
	local options: { TBuildingPickerOption } = {}
	for _, opt in rawOptions do
		table.insert(options, {
			BuildingType = opt.BuildingType,
			Cost = opt.Cost,
			MaxLevel = opt.MaxLevel,
			IsLocked = opt.IsLocked,
			IsAffordable = (opt.Cost.Gold or 0) <= gold,
			CostText = _formatCost(opt.Cost),
			MaxLevelText = "Max Lv." .. tostring(opt.MaxLevel),
		})
	end
	return table.freeze({ options = options } :: TBuildingPickerViewData)
end

--[=[
	Returns whether a specific option (by building type) can be confirmed.
	@within BuildingPickerViewModel
	@param options { TBuildingPickerOption } -- Enriched options list
	@param selectedType string? -- Currently selected building type
	@param isLoading boolean -- Whether a construction request is in flight
	@return boolean -- True if the confirm button should be active
]=]
function BuildingPickerViewModel.canConfirm(
	options: { TBuildingPickerOption },
	selectedType: string?,
	isLoading: boolean
): boolean
	if selectedType == nil or isLoading then
		return false
	end
	for _, opt in options do
		if opt.BuildingType == selectedType then
			return opt.IsAffordable and not opt.IsLocked
		end
	end
	return false
end

return BuildingPickerViewModel
