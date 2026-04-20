--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Errors = require(script.Parent.Parent.Parent.Errors)
local Result = require(ReplicatedStorage.Utilities.Result)
local Ok, Try, Ensure = Result.Ok, Result.Try, Result.Ensure
local MentionSuccess = Result.MentionSuccess

--[=[
	@class BuyItem
	Application command service for purchasing items from the shop.
	@server
]=]
local BuyItem = {}
BuyItem.__index = BuyItem

export type TBuyItem = typeof(setmetatable({} :: {
	_registry: any,
	BuyPolicy: any,
	GoldSyncService: any,
	InventoryContext: any,
}, BuyItem))

function BuyItem.new()
	return setmetatable({}, BuyItem)
end

--[=[
	Initialize BuyItem with registry access to policies and services.
	@within BuyItem
	@param registry any -- Service registry
	@param _name string -- Service name
]=]
function BuyItem:Init(registry: any, _name: string)
	self._registry = registry
	self.BuyPolicy = registry:Get("BuyPolicy")
	self.GoldSyncService = registry:Get("GoldSyncService")
end

--[=[
	Start BuyItem by resolving cross-context dependencies.
	@within BuyItem
]=]
function BuyItem:Start()
	self.InventoryContext = self._registry:Get("InventoryContext")
end

--[=[
	Execute a purchase: validate → deduct gold → add to inventory (with rollback on failure).
	@within BuyItem
	@param player Player -- The player making the purchase
	@param userId number -- The player's user ID
	@param itemId string -- The item to purchase
	@param quantity number -- How many to purchase
	@return Result<any> -- Success returns item, quantity, cost, and remaining gold; failure returns error
]=]
function BuyItem:Execute(player: Player, userId: number, itemId: string, quantity: number): Result.Result<any>
	Ensure(player ~= nil and userId > 0, "InvalidInput", Errors.PLAYER_NOT_FOUND)

	-- Step 1: Validate item, quantity, gold, and inventory space
	local ctx = Try(self.BuyPolicy:Check(player, userId, itemId, quantity))

	-- Step 2: Deduct gold from player balance
	Try(self.GoldSyncService:RemoveGold(player, userId, ctx.TotalCost))

	-- Step 3: Add items to inventory; rollback gold if add fails
	Try(self.InventoryContext:AddItemToInventory(userId, itemId, quantity)
		:orElse(function(err)
			self.GoldSyncService:AddGold(player, userId, ctx.TotalCost)
			return Result.Err("BuyFailed", Errors.BUY_FAILED, { userId = userId, reason = err.message })
		end))
	local remainingGold = self.GoldSyncService:GetGoldReadOnly(userId)
	MentionSuccess("Shop:BuyItem:Execute", "Purchased item and added inventory quantity", {
		userId = userId,
		itemId = itemId,
		quantity = quantity,
		totalCost = ctx.TotalCost,
	})

	return Ok({
		ItemId        = itemId,
		Quantity      = quantity,
		TotalCost     = ctx.TotalCost,
		RemainingGold = remainingGold,
	})
end

return BuyItem
