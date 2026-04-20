--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UpgradeConfig = require(ReplicatedStorage.Contexts.Upgrade.Config.UpgradeConfig)
local UpgradeTypes = require(ReplicatedStorage.Contexts.Upgrade.Types.UpgradeTypes)

type TUpgradeLevels = UpgradeTypes.TUpgradeLevels

--[=[
	@class ModifierAggregator
	Pure domain service that sums upgrade effect magnitudes into a single modifier value.

	Walks the UpgradeConfig table and sums `EffectMagnitudePerLevel * level`
	across all entries whose `ModifierId` matches the query.

	Returns the raw additive total (NOT `1 + total`) — callers compose further:
	- Multipliers:   final = 1 + aggregate
	- Discounts:     final = clamp(aggregate, 0, MaxDiscount)

	The aggregator is the single point where additive-within-upgrades math is
	resolved, preventing drift across consumer call-sites.
	@server
]=]

local ModifierAggregator = {}
ModifierAggregator.__index = ModifierAggregator

export type TModifierAggregator = typeof(setmetatable({}, ModifierAggregator))

function ModifierAggregator.new(): TModifierAggregator
	return setmetatable({}, ModifierAggregator)
end

--[=[
	Sums all matching upgrade contributions for a given modifier id.
	Optional `excludeUpgradeId` prevents an upgrade from modifying its own pricing.
	@within ModifierAggregator
	@param ownedLevels TUpgradeLevels
	@param modifierId string
	@param excludeUpgradeId string?
	@return number
]=]
function ModifierAggregator:Aggregate(
	ownedLevels: TUpgradeLevels,
	modifierId: string,
	excludeUpgradeId: string?
): number
	local total = 0
	for upgradeId, entry in UpgradeConfig.Entries do
		if entry.ModifierId ~= modifierId then
			continue
		end
		if excludeUpgradeId and upgradeId == excludeUpgradeId then
			continue
		end
		local level = ownedLevels[upgradeId] or 0
		if level <= 0 then
			continue
		end
		total += entry.EffectMagnitudePerLevel * level
	end
	return total
end

return ModifierAggregator
