--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Spec = require(ReplicatedStorage.Utilities.Specification)
local Errors = require(script.Parent.Parent.Parent.Errors)

--[=[
	@class ShopSpecs
	Composable eligibility specifications for buy and sell operations.
	@server
]=]

--[=[
	@interface TBuyCandidate
	@within ShopSpecs
	.ItemExists boolean -- Item ID exists in ItemConfig
	.ItemBuyable boolean -- Item has a BuyPrice in ItemConfig
	.QuantityValid boolean -- Buy quantity is at least 1
	.CanAfford boolean -- Player has enough gold for purchase
	.HasInventorySpace boolean -- Player's inventory has a free slot
	.IsUnlocked boolean -- Item is unlocked for this player
]=]
export type TBuyCandidate = {
	ItemExists: boolean,
	ItemBuyable: boolean,
	QuantityValid: boolean,
	CanAfford: boolean,
	HasInventorySpace: boolean,
	IsUnlocked: boolean,
}

--[=[
	@interface TSellCandidate
	@within ShopSpecs
	.SlotExists boolean -- Inventory slot at index contains an item
	.QuantityValid boolean -- Sell quantity is at least 1
	.ItemSellable boolean -- Item in slot has a SellPrice in ItemConfig
	.HasEnoughItems boolean -- Slot contains enough quantity to sell
]=]
export type TSellCandidate = {
	SlotExists: boolean,
	QuantityValid: boolean,
	ItemSellable: boolean,
	HasEnoughItems: boolean,
}

-- Individual specs

local ItemExists = Spec.new("InvalidItemId", Errors.INVALID_ITEM_ID,
	function(ctx: TBuyCandidate)
		return ctx.ItemExists
	end
)

local ItemBuyable = Spec.new("ItemNotBuyable", Errors.ITEM_NOT_BUYABLE,
	function(ctx: TBuyCandidate)
		return ctx.ItemBuyable
	end
)

local BuyQuantityValid = Spec.new("InvalidQuantity", Errors.INVALID_QUANTITY,
	function(ctx: TBuyCandidate)
		return ctx.QuantityValid
	end
)

local CanAffordItem = Spec.new("InsufficientGold", Errors.INSUFFICIENT_GOLD,
	function(ctx: TBuyCandidate)
		return ctx.CanAfford
	end
)

local HasInventorySpace = Spec.new("InventoryFull", Errors.INVENTORY_FULL,
	function(ctx: TBuyCandidate)
		return ctx.HasInventorySpace
	end
)

local ItemIsUnlocked = Spec.new("ItemLocked", Errors.ITEM_LOCKED,
	function(ctx: TBuyCandidate)
		return ctx.IsUnlocked
	end
)

local SlotExists = Spec.new("SlotEmpty", Errors.SLOT_EMPTY,
	function(ctx: TSellCandidate)
		return ctx.SlotExists
	end
)

local SellQuantityValid = Spec.new("InvalidQuantity", Errors.INVALID_QUANTITY,
	function(ctx: TSellCandidate)
		return ctx.QuantityValid
	end
)

local ItemSellable = Spec.new("ItemNotSellable", Errors.ITEM_NOT_SELLABLE,
	function(ctx: TSellCandidate)
		return ctx.ItemSellable
	end
)

local HasEnoughItems = Spec.new("InsufficientItemQuantity", Errors.INSUFFICIENT_ITEM_QUANTITY,
	function(ctx: TSellCandidate)
		return ctx.HasEnoughItems
	end
)

-- Composed specs

--[=[
	@prop CanBuy Spec
	@within ShopSpecs
	Composed spec: item must exist and be unlocked, buyable, quantity valid, affordable, and have inventory space.
]=]

--[=[
	@prop CanSell Spec
	@within ShopSpecs
	Composed spec: slot must exist, quantity valid, item sellable, and have enough items.
]=]

return table.freeze({
	CanBuy  = ItemExists:And(Spec.All({ ItemIsUnlocked, ItemBuyable, BuyQuantityValid, CanAffordItem, HasInventorySpace })),
	CanSell = SlotExists:And(Spec.All({ SellQuantityValid, ItemSellable, HasEnoughItems })),
})
