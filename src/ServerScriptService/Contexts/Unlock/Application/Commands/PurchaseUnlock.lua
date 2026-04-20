--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Result = require(ReplicatedStorage.Utilities.Result)

local Ok, Try, Ensure = Result.Ok, Result.Try, Result.Ensure
local MentionSuccess = Result.MentionSuccess

--[=[
	@class PurchaseUnlock
	Player-initiated unlock purchase. Validates eligibility via `PurchaseUnlockPolicy`,
	deducts gold if required, marks the target as unlocked, persists, and syncs.
	@server
]=]

local PurchaseUnlock = {}
PurchaseUnlock.__index = PurchaseUnlock

function PurchaseUnlock.new()
	return setmetatable({}, PurchaseUnlock)
end

--[=[
	@within PurchaseUnlock
	@private
]=]
function PurchaseUnlock:Init(registry: any, _name: string)
	self.PurchaseUnlockPolicy = registry:Get("PurchaseUnlockPolicy")
	self.UnlockSyncService = registry:Get("UnlockSyncService")
	self.UnlockPersistenceService = registry:Get("UnlockPersistenceService")
	self.Registry = registry
end

--[=[
	@within PurchaseUnlock
	@private
]=]
function PurchaseUnlock:Start()
	self.ShopContext = self.Registry:Get("ShopContext")
end

--[=[
	Validates inputs, deducts cost, applies the unlock, and persists.
	@within PurchaseUnlock
	@param player Player -- The purchasing player
	@param userId number -- The player's user ID
	@param targetId string -- The unlock target to purchase
	@return Result.Result<boolean> -- Ok(true) on success, Err on failure
]=]
function PurchaseUnlock:Execute(player: Player, userId: number, targetId: string): Result.Result<boolean>
	-- Validate player and target ID formats
	self:_ValidateInputs(player, userId, targetId)

	-- Check eligibility; returns GoldCost needed
	local purchaseTerms = Try(self.PurchaseUnlockPolicy:Check(userId, targetId))

	-- Deduct cost from gold if required
	self:_DeductCostIfRequired(player, userId, purchaseTerms.GoldCost)

	-- Mark unlocked and persist
	self:_ApplyUnlock(player, userId, targetId)

	MentionSuccess("Unlock:PurchaseUnlock:Execute", "Purchased and persisted unlock target", {
		userId = userId,
		targetId = targetId,
		goldCost = purchaseTerms.GoldCost,
	})
	return Ok(true)
end

--[=[
	@within PurchaseUnlock
	@private
]=]
function PurchaseUnlock:_ValidateInputs(player: Player, userId: number, targetId: string)
	Ensure(player ~= nil and userId > 0, "InvalidInput", "Invalid player or userId")
	Ensure(type(targetId) == "string" and #targetId > 0, "InvalidInput", "Invalid targetId")
end

--[=[
	@within PurchaseUnlock
	@private
]=]
function PurchaseUnlock:_DeductCostIfRequired(player: Player, userId: number, goldCost: number)
	if goldCost > 0 then
		Try(self.ShopContext:DeductGold(player, userId, goldCost))
	end
end

--[=[
	@within PurchaseUnlock
	@private
]=]
function PurchaseUnlock:_ApplyUnlock(player: Player, userId: number, targetId: string)
	-- Mark target as unlocked in the atom
	self.UnlockSyncService:MarkUnlocked(userId, targetId)

	-- Fetch the updated state and persist
	local finalState = self.UnlockSyncService:GetUnlockStateReadOnly(userId)
	if finalState then
		Try(self.UnlockPersistenceService:SaveUnlockData(player, finalState))
	end

	-- Sync new state to client
	self.UnlockSyncService:HydratePlayer(player)
end

return PurchaseUnlock
