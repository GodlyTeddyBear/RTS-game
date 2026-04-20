--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Errors = require(script.Parent.Parent.Parent.Errors)
local Result = require(ReplicatedStorage.Utilities.Result)
local Ok, Try, Ensure = Result.Ok, Result.Try, Result.Ensure
local MentionSuccess = Result.MentionSuccess
local GameEvents = require(ReplicatedStorage.Events.GameEvents)

local Events = GameEvents.Events

--[=[
	@class SellItem
	Application command service for selling items to the shop.
	@server
]=]
local SellItem = {}
SellItem.__index = SellItem

export type TSellItem = typeof(setmetatable({} :: {
	_registry: any,
	SellPolicy: any,
	GoldSyncService: any,
	InventoryContext: any,
}, SellItem))

function SellItem.new()
	return setmetatable({}, SellItem)
end

--[=[
	Initialize SellItem with registry access to policies and services.
	@within SellItem
	@param registry any -- Service registry
	@param _name string -- Service name
]=]
function SellItem:Init(registry: any, _name: string)
	self._registry = registry
	self.SellPolicy = registry:Get("SellPolicy")
	self.GoldSyncService = registry:Get("GoldSyncService")
end

--[=[
	Start SellItem by resolving cross-context dependencies.
	@within SellItem
]=]
function SellItem:Start()
	self.InventoryContext = self._registry:Get("InventoryContext")
end

--[=[
	Execute a sale: validate → remove from inventory → add gold (with rollback on failure).
	@within SellItem
	@param player Player -- The player selling the item
	@param userId number -- The player's user ID
	@param slotIndex number -- The inventory slot index
	@param quantity number -- How many to sell
	@return Result<any> -- Success returns item, quantity, revenue, and new gold; failure returns error
]=]
function SellItem:Execute(player: Player, userId: number, slotIndex: number, quantity: number): Result.Result<any>
	Ensure(player ~= nil and userId > 0, "InvalidInput", Errors.PLAYER_NOT_FOUND)

	-- Step 1: Validate slot, item sellability, and quantity
	local ctx = Try(self.SellPolicy:Check(userId, slotIndex, quantity))

	-- Step 2: Remove items from inventory
	Try(self.InventoryContext:RemoveItemFromInventory(userId, slotIndex, quantity)
		:orElse(function(err)
			return Result.Err("SellFailed", Errors.SELL_FAILED, { userId = userId, reason = err.message })
		end))

	-- Step 3: Add gold to player; rollback items if add fails
	Try(self.GoldSyncService:AddGold(player, userId, ctx.TotalRevenue)
		:orElse(function()
			self.InventoryContext:AddItemToInventory(userId, ctx.Slot.ItemId, quantity)
			return Result.Err("SellFailed", Errors.SELL_FAILED, { userId = userId })
		end))
	local newGold = self.GoldSyncService:GetGoldReadOnly(userId)
	GameEvents.Bus:Emit(Events.Inventory.ItemSold, userId, ctx.Slot.ItemId, quantity, ctx.TotalRevenue)
	MentionSuccess("Shop:SellItem:Execute", "Sold inventory item and credited player gold", {
		userId = userId,
		itemId = ctx.Slot.ItemId,
		quantity = quantity,
		totalRevenue = ctx.TotalRevenue,
	})

	return Ok({
		ItemId       = ctx.Slot.ItemId,
		Quantity     = quantity,
		TotalRevenue = ctx.TotalRevenue,
		NewGold      = newGold,
	})
end

return SellItem
