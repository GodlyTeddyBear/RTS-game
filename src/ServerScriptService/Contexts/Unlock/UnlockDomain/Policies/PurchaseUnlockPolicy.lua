--!strict

--[=[
	@class PurchaseUnlockPolicy
	Domain policy that answers: can this player purchase this unlock?

	Validates that the target exists, is not an auto-unlock, and that the player
	meets all configured conditions. Returns `Ok({ GoldCost })` so the calling
	command knows how much gold to deduct.

	**Result:**
	- `Ok({ GoldCost })` — purchase is valid; gold cost returned for command use
	- `Err(...)` — player not loaded, already unlocked, or conditions not met
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UnlockConfig = require(ReplicatedStorage.Contexts.Unlock.Config.UnlockConfig)
local Result = require(ReplicatedStorage.Utilities.Result)
local Errors = require(script.Parent.Parent.Parent.Errors)

local Ok, Ensure = Result.Ok, Result.Ensure

local PurchaseUnlockPolicy = {}
PurchaseUnlockPolicy.__index = PurchaseUnlockPolicy

export type TPurchaseUnlockPolicy = typeof(setmetatable({}, PurchaseUnlockPolicy))

function PurchaseUnlockPolicy.new(): TPurchaseUnlockPolicy
	return setmetatable({}, PurchaseUnlockPolicy)
end

--[=[
	@within PurchaseUnlockPolicy
	@private
]=]
function PurchaseUnlockPolicy:Init(registry: any)
	self.UnlockSyncService = registry:Get("UnlockSyncService")
	self.UnlockConditionResolver = registry:Get("UnlockConditionResolver")
	self.UnlockConditionEvaluator = registry:Get("UnlockConditionEvaluator")
	self._registry = registry
end

--[=[
	@within PurchaseUnlockPolicy
	@private
]=]
function PurchaseUnlockPolicy:Start()
	self.UpgradeContext = self._registry:Get("UpgradeContext")
end

--[=[
	Evaluates whether a player can purchase a specific unlock target.
	@within PurchaseUnlockPolicy
	@param userId number -- The player's user ID
	@param targetId string -- The unlock target to evaluate
	@return Result.Result<{ GoldCost: number }> -- Ok with gold cost on success, Err on ineligibility
]=]
function PurchaseUnlockPolicy:Check(userId: number, targetId: string): Result.Result<{ GoldCost: number }>
	-- Validate target exists and is purchasable (not auto-unlock)
	local entry = UnlockConfig[targetId]
	Ensure(entry ~= nil, "TargetNotFound", Errors.TARGET_NOT_FOUND)
	Ensure(not entry.AutoUnlock, "NotPurchasable", Errors.IS_AUTO_UNLOCK)

	-- Load player's current unlock state
	local state = self.UnlockSyncService:GetUnlockStateReadOnly(userId)
	Ensure(state ~= nil, "PlayerNotFound", Errors.PLAYER_NOT_FOUND)
	Ensure(state[targetId] ~= true, "AlreadyUnlocked", Errors.ALREADY_UNLOCKED)

	-- Evaluate all conditions
	local snapshot = self.UnlockConditionResolver:Resolve(userId)
	local isEligible, failure = self.UnlockConditionEvaluator:MeetsAll(entry.Conditions, snapshot, { IgnoreGold = false })
	Ensure(isEligible, "ConditionNotMet", if failure then failure.Message else "Unlock condition not met")

	-- Apply shop discount (shared with Shop buys) to the gold cost
	local rawCost = entry.Conditions.Gold or 0
	local finalCost = rawCost
	if rawCost > 0 and self.UpgradeContext then
		local discount = self.UpgradeContext:GetShopDiscount(userId)
		finalCost = math.max(1, math.floor(rawCost * (1 - discount)))
	end

	-- Return cost for command to deduct
	return Ok({ GoldCost = finalCost })
end

return PurchaseUnlockPolicy
