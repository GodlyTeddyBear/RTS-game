--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UnitConfig = require(ReplicatedStorage.Contexts.Unit.Config.UnitConfig)
local UnitTypes = require(ReplicatedStorage.Contexts.Unit.Types.UnitTypes)

type UnitDefinition = UnitTypes.UnitDefinition

export type TUnitProductionCardData = {
	unitId: string,
	displayName: string,
	hpText: string,
	capText: string,
	isSelected: boolean,
	isProduceEnabled: boolean,
	layoutOrder: number,
}

export type TBaseProductionViewData = {
	title: string,
	subtitle: string,
	selectedUnitId: string?,
	units: { TUnitProductionCardData },
}

local BaseProductionViewModel = {}

local function _BuildOrderedUnitIds(definitions: { [string]: UnitDefinition }): { string }
	local unitIds = {}
	for unitId in definitions do
		table.insert(unitIds, unitId)
	end

	table.sort(unitIds)
	return unitIds
end

function BaseProductionViewModel.fromUnitConfig(selectedUnitId: string?): TBaseProductionViewData
	local orderedUnitIds = _BuildOrderedUnitIds(UnitConfig.Definitions)
	local units = table.create(#orderedUnitIds)

	for index, unitId in ipairs(orderedUnitIds) do
		local definition = UnitConfig.Definitions[unitId]
		units[#units + 1] = table.freeze({
			unitId = unitId,
			displayName = definition.DisplayName,
			hpText = ("%d HP"):format(definition.Health.Max),
			capText = ("Cap %d"):format(definition.Limits.MaxConcurrentPerOwner),
			isSelected = selectedUnitId == unitId,
			isProduceEnabled = true,
			layoutOrder = index,
		} :: TUnitProductionCardData)
	end

	return table.freeze({
		title = "BASE PRODUCTION",
		subtitle = "Select a unit to deploy",
		selectedUnitId = selectedUnitId,
		units = table.freeze(units),
	} :: TBaseProductionViewData)
end

return BaseProductionViewModel
