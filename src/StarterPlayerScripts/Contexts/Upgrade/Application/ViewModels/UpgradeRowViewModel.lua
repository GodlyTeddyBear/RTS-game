--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UpgradeConfig = require(ReplicatedStorage.Contexts.Upgrade.Config.UpgradeConfig)
local UpgradeTypes = require(ReplicatedStorage.Contexts.Upgrade.Types.UpgradeTypes)

type TUpgradeLevels = UpgradeTypes.TUpgradeLevels

--[=[
	@interface TUpgradeRowViewModel
	Row display model for a single upgrade entry.
	.Id string
	.DisplayName string
	.Description string
	.CurrentLevel number
	.MaxLevel number
	.IsMaxed boolean
	.NextCost number -- 0 when maxed
	.CanAfford boolean
	.EffectText string -- formatted e.g. "+5% per level"
]=]
export type TUpgradeRowViewModel = {
	Id: string,
	DisplayName: string,
	Description: string,
	CurrentLevel: number,
	MaxLevel: number,
	IsMaxed: boolean,
	NextCost: number,
	CanAfford: boolean,
	EffectText: string,
}

local UpgradeRowViewModel = {}

local function formatEffect(entry: any): string
	local pct = math.floor(entry.EffectMagnitudePerLevel * 100 + 0.5)
	return "+" .. tostring(pct) .. "% per level"
end

local function computeNextCost(entry: any, currentLevel: number): number
	if currentLevel >= entry.MaxLevel then
		return 0
	end
	return math.floor(entry.BaseCost * (entry.CostGrowth ^ currentLevel))
end

--[=[
	@within UpgradeRowViewModel
	Builds a row view model from raw config + current level + current gold.
	@param upgradeId string
	@param currentLevel number
	@param currentGold number
	@return TUpgradeRowViewModel?
]=]
function UpgradeRowViewModel.fromConfig(
	upgradeId: string,
	currentLevel: number,
	currentGold: number
): TUpgradeRowViewModel?
	local entry = UpgradeConfig.Entries[upgradeId]
	if not entry then
		return nil
	end
	local isMaxed = currentLevel >= entry.MaxLevel
	local nextCost = computeNextCost(entry, currentLevel)
	return {
		Id = entry.Id,
		DisplayName = entry.DisplayName,
		Description = entry.Description,
		CurrentLevel = currentLevel,
		MaxLevel = entry.MaxLevel,
		IsMaxed = isMaxed,
		NextCost = nextCost,
		CanAfford = not isMaxed and currentGold >= nextCost,
		EffectText = formatEffect(entry),
	}
end

--[=[
	@within UpgradeRowViewModel
	Produces the full list of row view models in config order.
	@param levels TUpgradeLevels
	@param currentGold number
	@return { TUpgradeRowViewModel }
]=]
function UpgradeRowViewModel.all(levels: TUpgradeLevels, currentGold: number): { TUpgradeRowViewModel }
	local rows: { TUpgradeRowViewModel } = {}
	for upgradeId in UpgradeConfig.Entries do
		local level = levels[upgradeId] or 0
		local vm = UpgradeRowViewModel.fromConfig(upgradeId, level, currentGold)
		if vm then
			table.insert(rows, vm)
		end
	end
	table.sort(rows, function(a, b)
		return a.DisplayName < b.DisplayName
	end)
	return rows
end

return UpgradeRowViewModel
