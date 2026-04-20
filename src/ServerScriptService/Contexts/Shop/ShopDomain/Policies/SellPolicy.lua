--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Result = require(ReplicatedStorage.Utilities.Result)
local Ok, Try = Result.Ok, Result.Try

local ItemConfig = require(ReplicatedStorage.Contexts.Inventory.Config.ItemConfig)
local ShopSpecs = require(script.Parent.Parent.Specs.ShopSpecs)

--[=[
	@class SellPolicy
	Domain policy evaluating sale eligibility.
	@server
]=]
local SellPolicy = {}
SellPolicy.__index = SellPolicy

--[=[
	@type TSellPolicyResult
	@within SellPolicy
	Result type returned by SellPolicy:Check on success.
	.Slot any -- The inventory slot data
	.TotalRevenue number -- Total revenue from the sale
]=]
export type TSellPolicyResult = {
	Slot: any,
	TotalRevenue: number,
}

export type TSellPolicy = typeof(setmetatable(
	{} :: {
		_registry: any,
		_inventoryContext: any,
	},
	SellPolicy
))

function SellPolicy.new(): TSellPolicy
	local self = setmetatable({}, SellPolicy)
	self._registry = nil :: any
	self._inventoryContext = nil :: any
	return self
end

--[=[
	Initialize SellPolicy with registry access to services.
	@within SellPolicy
	@param registry any -- Service registry
	@param _name string -- Service name
]=]
function SellPolicy:Init(registry: any, _name: string)
	self._registry = registry
end

--[=[
	Start SellPolicy by resolving cross-context dependencies.
	@within SellPolicy
]=]
function SellPolicy:Start()
	self._inventoryContext = self._registry:Get("InventoryContext")
end

--[=[
	Check if a player can sell items from an inventory slot.
	@within SellPolicy
	@param userId number -- The player's user ID
	@param slotIndex number -- The inventory slot index
	@param quantity number -- The quantity to sell
	@return Result<TSellPolicyResult> -- Success with slot and revenue, or failure with policy violation
	@yields
]=]
function SellPolicy:Check(userId: number, slotIndex: number, quantity: number): Result.Result<TSellPolicyResult>
	-- Step 1: Fetch inventory state from cross-context dependency
	local inventoryState = Try(self._inventoryContext:GetPlayerInventory(userId))

	-- Step 2: Extract slot and item data from inventory
	local slot = inventoryState and inventoryState.Slots and inventoryState.Slots[slotIndex]
	local itemData = slot and ItemConfig[slot.ItemId]
	local sellPrice = itemData and itemData.SellPrice
	local totalRevenue = sellPrice and (sellPrice * quantity) or 0

	-- Step 3: Build candidate for spec evaluation
	local candidate: ShopSpecs.TSellCandidate = {
		SlotExists    = slot ~= nil,
		QuantityValid = quantity >= 1,
		-- Pass when slot is absent (SlotExists will fail first via And)
		ItemSellable  = slot == nil or (itemData ~= nil and sellPrice ~= nil),
		HasEnoughItems = slot == nil or quantity <= slot.Quantity,
	}

	-- Step 4: Evaluate composed spec; fails fast on first violation
	Try(ShopSpecs.CanSell:IsSatisfiedBy(candidate))

	return Ok({
		Slot         = slot,
		TotalRevenue = totalRevenue,
	})
end

return SellPolicy
