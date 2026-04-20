--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Result = require(ReplicatedStorage.Utilities.Result)
local Ok, Try = Result.Ok, Result.Try

local ItemConfig = require(ReplicatedStorage.Contexts.Inventory.Config.ItemConfig)
local UnlockConfig = require(ReplicatedStorage.Contexts.Unlock.Config.UnlockConfig)
local ShopSpecs = require(script.Parent.Parent.Specs.ShopSpecs)

--[=[
	@class BuyPolicy
	Domain policy evaluating purchase eligibility.
	@server
]=]
local BuyPolicy = {}
BuyPolicy.__index = BuyPolicy

--[=[
	@type TBuyPolicyResult
	@within BuyPolicy
	Result type returned by BuyPolicy:Check on success.
	.TotalCost number -- Total cost of the purchase
]=]
export type TBuyPolicyResult = {
	TotalCost: number,
}

export type TBuyPolicy = typeof(setmetatable(
	{} :: {
		_registry: any,
		_goldSyncService: any,
		_inventoryContext: any,
		_unlockContext: any,
		_upgradeContext: any,
	},
	BuyPolicy
))

function BuyPolicy.new(): TBuyPolicy
	local self = setmetatable({}, BuyPolicy)
	self._registry = nil :: any
	self._goldSyncService = nil :: any
	self._inventoryContext = nil :: any
	self._unlockContext = nil :: any
	self._upgradeContext = nil :: any
	return self
end

--[=[
	Initialize BuyPolicy with registry access to services.
	@within BuyPolicy
	@param registry any -- Service registry
	@param _name string -- Service name
]=]
function BuyPolicy:Init(registry: any, _name: string)
	self._registry = registry
	self._goldSyncService = registry:Get("GoldSyncService")
end

--[=[
	Start BuyPolicy by resolving cross-context dependencies.
	@within BuyPolicy
]=]
function BuyPolicy:Start()
	self._inventoryContext = self._registry:Get("InventoryContext")
	self._unlockContext = self._registry:Get("UnlockContext")
	self._upgradeContext = self._registry:Get("UpgradeContext")
end

--[=[
	Check if a player can buy an item in the requested quantity.
	@within BuyPolicy
	@param player Player -- The player attempting to buy
	@param userId number -- The player's user ID
	@param itemId string -- The item to buy
	@param quantity number -- The quantity to buy
	@return Result<TBuyPolicyResult> -- Success with total cost, or failure with policy violation
	@yields
]=]
function BuyPolicy:Check(player: Player, userId: number, itemId: string, quantity: number): Result.Result<TBuyPolicyResult>
	-- Step 1: Fetch current state from services
	local currentGold = self._goldSyncService:GetGoldReadOnly(userId)
	local inventoryState = Try(self._inventoryContext:GetPlayerInventory(userId))

	-- Step 2: Look up item and unlock config
	local itemData = ItemConfig[itemId]
	local buyPrice = itemData and itemData.BuyPrice
	local totalCost = buyPrice and (buyPrice * quantity) or 0
	if buyPrice and self._upgradeContext then
		local discount = self._upgradeContext:GetShopDiscount(userId)
		totalCost = math.max(1, math.floor(totalCost * (1 - discount)))
	end
	local hasUnlockCoverage = UnlockConfig[itemId] ~= nil

	-- Step 3: Extract inventory capacity from metadata
	local usedSlots = inventoryState and inventoryState.Metadata and (inventoryState.Metadata.UsedSlots or 0) or 0
	local totalSlots = inventoryState and inventoryState.Metadata and (inventoryState.Metadata.TotalSlots or 200) or 200

	-- Step 4: Build candidate for spec evaluation
	local candidate: ShopSpecs.TBuyCandidate = {
		ItemExists        = itemData ~= nil,
		ItemBuyable       = itemData ~= nil and buyPrice ~= nil,
		QuantityValid     = quantity >= 1,
		-- Pass when item/price unknown (ItemExists/ItemBuyable will fail first via And)
		CanAfford         = buyPrice == nil or currentGold >= totalCost,
		HasInventorySpace = usedSlots < totalSlots,
		-- Shop strict mode: missing unlock coverage is treated as locked
		IsUnlocked        = hasUnlockCoverage and self._unlockContext:IsUnlocked(userId, itemId),
	}

	-- Step 5: Evaluate composed spec; fails fast on first violation
	Try(ShopSpecs.CanBuy:IsSatisfiedBy(candidate))

	return Ok({
		TotalCost = totalCost,
	})
end

return BuyPolicy
