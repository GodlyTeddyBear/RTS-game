--!strict

local UpgradeId = require(script.Parent.Parent.Types.UpgradeId)

export type TUpgradeEntry = {
	Id: string,
	DisplayName: string,
	Description: string,
	ModifierId: string,
	EffectMagnitudePerLevel: number,
	MaxLevel: number,
	BaseCost: number,
	CostGrowth: number,
}

-- Maximum combined discount magnitude applied to any price.
-- Clamps total discount into [0, MAX_DISCOUNT] to prevent free purchases.
local MAX_DISCOUNT = 0.75

-- UpgradeCostDiscount applies to every upgrade *except itself*. This is enforced
-- in UpgradeContext:GetUpgradeCostDiscount to prevent a compounding death spiral
-- where buying the discount makes future levels of itself cheaper.
local UpgradeConfig: { [string]: TUpgradeEntry } = {
	[UpgradeId.GoldGain] = {
		Id = UpgradeId.GoldGain,
		DisplayName = "Gold Gain",
		Description = "All gold income +5% per level.",
		ModifierId = "GoldMultiplier",
		EffectMagnitudePerLevel = 0.05,
		MaxLevel = 20,
		BaseCost = 500,
		CostGrowth = 1.5,
	},

	[UpgradeId.WorkerXP] = {
		Id = UpgradeId.WorkerXP,
		DisplayName = "Worker XP",
		Description = "Workers earn +10% XP per level.",
		ModifierId = "WorkerXPMultiplier",
		EffectMagnitudePerLevel = 0.1,
		MaxLevel = 10,
		BaseCost = 1000,
		CostGrowth = 1.6,
	},

	[UpgradeId.ShopDiscount] = {
		Id = UpgradeId.ShopDiscount,
		DisplayName = "Shop Discount",
		Description = "Purchases cost 2% less per level.",
		ModifierId = "ShopDiscount",
		EffectMagnitudePerLevel = 0.02,
		MaxLevel = 15,
		BaseCost = 2000,
		CostGrowth = 1.7,
	},

	[UpgradeId.UpgradeCostDiscount] = {
		Id = UpgradeId.UpgradeCostDiscount,
		DisplayName = "Upgrade Cost Discount",
		Description = "Other upgrades cost 2% less per level.",
		ModifierId = "UpgradeCostDiscount",
		EffectMagnitudePerLevel = 0.02,
		MaxLevel = 10,
		BaseCost = 5000,
		CostGrowth = 1.8,
	},
}

table.freeze(UpgradeConfig)

return {
	Entries = UpgradeConfig,
	MaxDiscount = MAX_DISCOUNT,
}
