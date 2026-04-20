--!strict

--[=[
	@class PurchaseUpgradePolicy
	Domain policy that answers: can this player purchase the next level of this upgrade?

	Validates that the upgrade exists, is not maxed, and that the player has
	enough gold (discounted by any applicable cost-reduction modifiers).

	Returns `Ok({ Cost, NewLevel })` so the calling command knows the final
	price to deduct and what level to set.

	**Result:**
	- `Ok({ Cost, NewLevel })` — purchase is valid
	- `Err(...)` — upgrade missing, player not loaded, maxed, or insufficient gold
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UpgradeConfig = require(ReplicatedStorage.Contexts.Upgrade.Config.UpgradeConfig)
local Result = require(ReplicatedStorage.Utilities.Result)
local UpgradeSpecs = require(script.Parent.Parent.Specs.UpgradeSpecs)
local Errors = require(script.Parent.Parent.Parent.Errors)

local Ok, Try, Ensure = Result.Ok, Result.Try, Result.Ensure

local PurchaseUpgradePolicy = {}
PurchaseUpgradePolicy.__index = PurchaseUpgradePolicy

export type TPurchaseUpgradePolicy = typeof(setmetatable({}, PurchaseUpgradePolicy))

export type TPurchaseTerms = {
	Cost: number,
	NewLevel: number,
}

function PurchaseUpgradePolicy.new(): TPurchaseUpgradePolicy
	return setmetatable({}, PurchaseUpgradePolicy)
end

--[=[
	@within PurchaseUpgradePolicy
	@private
]=]
function PurchaseUpgradePolicy:Init(registry: any)
	self.UpgradeSyncService = registry:Get("UpgradeSyncService")
	self.ModifierAggregator = registry:Get("ModifierAggregator")
	self.Registry = registry
end

--[=[
	@within PurchaseUpgradePolicy
	@private
]=]
function PurchaseUpgradePolicy:Start()
	self.ShopContext = self.Registry:Get("ShopContext")
end

--[=[
	Evaluates whether a player can purchase the next level of a specific upgrade.
	@within PurchaseUpgradePolicy
	@param userId number
	@param upgradeId string
	@return Result.Result<TPurchaseTerms>
]=]
function PurchaseUpgradePolicy:Check(userId: number, upgradeId: string): Result.Result<TPurchaseTerms>
	local entry = UpgradeConfig.Entries[upgradeId]
	local upgradeExists = entry ~= nil
	Ensure(upgradeExists, "UpgradeNotFound", Errors.UPGRADE_NOT_FOUND)

	local levels = self.UpgradeSyncService:GetUpgradeLevelsReadOnly(userId)
	Ensure(levels ~= nil, "PlayerNotFound", Errors.PLAYER_NOT_FOUND)

	local currentLevel = levels[upgradeId] or 0
	local notMaxed = currentLevel < entry.MaxLevel

	local finalCost = self:_ComputeFinalCost(levels, entry, currentLevel, upgradeId)
	local currentGold = Try(self.ShopContext:GetPlayerGold(userId))
	local canAfford = currentGold >= finalCost

	local candidate = {
		UpgradeExists = upgradeExists,
		NotMaxed = notMaxed,
		CanAfford = canAfford,
	}

	Try(UpgradeSpecs.CanPurchase:IsSatisfiedBy(candidate))

	return Ok({
		Cost = finalCost,
		NewLevel = currentLevel + 1,
	})
end

--[=[
	@within PurchaseUpgradePolicy
	@private
]=]
function PurchaseUpgradePolicy:_ComputeFinalCost(
	levels: any,
	entry: any,
	currentLevel: number,
	upgradeId: string
): number
	local rawCost = math.floor(entry.BaseCost * (entry.CostGrowth ^ currentLevel))
	local discount = self.ModifierAggregator:Aggregate(levels, "UpgradeCostDiscount", upgradeId)
	discount = math.clamp(discount, 0, UpgradeConfig.MaxDiscount)
	return math.max(1, math.floor(rawCost * (1 - discount)))
end

return PurchaseUpgradePolicy
