--!strict

--[=[
    @class InventorySpecs
    Composable eligibility specifications for all inventory operations.
    @server
]=]

--[=[
    @interface TAddItemCandidate
    @within InventorySpecs
    .ItemExists boolean -- Whether the item ID exists in ItemConfig
    .AddQuantityValid boolean -- Whether the quantity is between 1 and maxStack
    .InventoryNotFull boolean -- Whether the inventory has at least one free slot
    .CategoryNotFull boolean -- Whether the item's category has available capacity
]=]

--[=[
    @interface TRemoveItemCandidate
    @within InventorySpecs
    .SlotValid boolean -- Whether the slot index is within inventory bounds
    .SlotOccupied boolean -- Whether the target slot contains an item
    .RemoveQuantityValid boolean -- Whether the quantity is at least 1
    .SufficientQuantity boolean -- Whether the slot has enough items to remove
]=]

--[=[
    @interface TTransferItemCandidate
    @within InventorySpecs
    .NotSameSlot boolean -- Whether source and destination indices differ
    .FromSlotValid boolean -- Whether the source slot index is within bounds
    .FromSlotOccupied boolean -- Whether the source slot contains an item
    .ToSlotValid boolean -- Whether the destination slot index is within bounds
]=]

--[=[
    @interface TStackItemsCandidate
    @within InventorySpecs
    .ItemExists boolean -- Whether the item ID exists in ItemConfig
    .ItemStackable boolean -- Whether the item has `stackable = true` in ItemConfig
]=]

--[[
	InventorySpecs — Composable eligibility rules for inventory operations.

	Each spec is a module-level constant built from Spec.new(). Specs are
	pure predicates: given a candidate, return true (Ok) or false (Err).
	They never fetch state — they receive it via the candidate.

	CANDIDATE TYPES:
	  TAddItemCandidate      — state needed to evaluate an add eligibility
	  TRemoveItemCandidate   — state needed to evaluate a remove eligibility
	  TTransferItemCandidate — state needed to evaluate a transfer eligibility
	  TStackItemsCandidate   — state needed to evaluate a stack eligibility

	INDIVIDUAL SPECS:
	  AddItemExists      — item ID exists in ItemConfig (can add)
	  AddQuantityValid   — add quantity is at least 1 and within maxStack
	  InventoryNotFull   — inventory has at least one free slot
	  CategoryNotFull    — item's category has available capacity

	  SlotValid          — slot index is within inventory bounds
	  SlotOccupied       — slot at index contains an item (defensive: true when out of bounds)
	  RemoveQuantityValid — remove quantity is at least 1
	  SufficientQuantity — slot has enough items to satisfy remove quantity (defensive: true when slot nil)

	  NotSameSlot        — source and destination slots are different indices
	  FromSlotValid      — from-slot index is within inventory bounds
	  FromSlotOccupied   — from-slot contains an item (defensive: true when out of bounds)
	  ToSlotValid        — to-slot index is within inventory bounds

	  StackItemExists    — item ID exists in ItemConfig (can stack)
	  ItemStackable      — item has stackable = true in ItemConfig (defensive: true when item nil)

	COMPOSED SPECS:
	  CanAddItem      — AddItemExists:And(All({ AddQuantityValid, InventoryNotFull, CategoryNotFull }))
	  CanRemoveItem   — SlotValid:And(All({ SlotOccupied, RemoveQuantityValid, SufficientQuantity }))
	  CanTransferItem — NotSameSlot:And(All({ FromSlotValid, FromSlotOccupied, ToSlotValid }))
	  CanStackItem    — StackItemExists:And(ItemStackable)

	CANDIDATE CONSTRUCTION NOTE:
	  When a prerequisite spec is false (AddItemExists, SlotValid, FromSlotValid, StackItemExists),
	  dependent specs are set to true so only the root error is reported. The And
	  composition short-circuits on the prerequisite, making this a safety net for
	  Spec.All accumulation.

	USAGE:
	  -- Inside a Catch boundary (typically in a Policy):
	  Try(InventorySpecs.CanAddItem:IsSatisfiedBy(candidate))
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Spec = require(ReplicatedStorage.Utilities.Specification)
local Errors = require(script.Parent.Parent.Parent.Errors)

-- Candidate types

export type TAddItemCandidate = {
	ItemExists: boolean,
	AddQuantityValid: boolean,
	InventoryNotFull: boolean,
	CategoryNotFull: boolean,
}

export type TRemoveItemCandidate = {
	SlotValid: boolean,
	SlotOccupied: boolean,
	RemoveQuantityValid: boolean,
	SufficientQuantity: boolean,
}

export type TTransferItemCandidate = {
	NotSameSlot: boolean,
	FromSlotValid: boolean,
	FromSlotOccupied: boolean,
	ToSlotValid: boolean,
}

export type TStackItemsCandidate = {
	ItemExists: boolean,
	ItemStackable: boolean,
}

-- Individual specs — Add item

local AddItemExists = Spec.new("InvalidItemId", Errors.INVALID_ITEM_ID,
	function(ctx: TAddItemCandidate) return ctx.ItemExists end
)

local AddQuantityValid = Spec.new("InvalidQuantity", Errors.INVALID_QUANTITY,
	function(ctx: TAddItemCandidate) return ctx.AddQuantityValid end
)

local InventoryNotFull = Spec.new("InventoryFull", Errors.INVENTORY_FULL,
	function(ctx: TAddItemCandidate) return ctx.InventoryNotFull end
)

local CategoryNotFull = Spec.new("CategoryFull", Errors.CATEGORY_FULL,
	function(ctx: TAddItemCandidate) return ctx.CategoryNotFull end
)

-- Individual specs — Remove item

local SlotValid = Spec.new("InvalidSlotIndex", Errors.INVALID_SLOT_INDEX,
	function(ctx: TRemoveItemCandidate) return ctx.SlotValid end
)

local SlotOccupied = Spec.new("SlotEmpty", Errors.SLOT_EMPTY,
	function(ctx: TRemoveItemCandidate) return ctx.SlotOccupied end
)

local RemoveQuantityValid = Spec.new("InvalidQuantity", Errors.INVALID_QUANTITY,
	function(ctx: TRemoveItemCandidate) return ctx.RemoveQuantityValid end
)

local SufficientQuantity = Spec.new("InsufficientQuantity", Errors.INSUFFICIENT_QUANTITY,
	function(ctx: TRemoveItemCandidate) return ctx.SufficientQuantity end
)

-- Individual specs — Transfer item

local NotSameSlot = Spec.new("InvalidTransfer", Errors.INVALID_TRANSFER,
	function(ctx: TTransferItemCandidate) return ctx.NotSameSlot end
)

local FromSlotValid = Spec.new("InvalidSlotIndex", Errors.INVALID_SLOT_INDEX,
	function(ctx: TTransferItemCandidate) return ctx.FromSlotValid end
)

local FromSlotOccupied = Spec.new("SlotEmpty", Errors.SLOT_EMPTY,
	function(ctx: TTransferItemCandidate) return ctx.FromSlotOccupied end
)

local ToSlotValid = Spec.new("InvalidSlotIndex", Errors.INVALID_SLOT_INDEX,
	function(ctx: TTransferItemCandidate) return ctx.ToSlotValid end
)

-- Individual specs — Stack items

local StackItemExists = Spec.new("InvalidItemId", Errors.INVALID_ITEM_ID,
	function(ctx: TStackItemsCandidate) return ctx.ItemExists end
)

local ItemStackable = Spec.new("ItemNotStackable", Errors.ITEM_NOT_STACKABLE,
	function(ctx: TStackItemsCandidate) return ctx.ItemStackable end
)

-- Composed specs

--[=[
    @prop CanAddItem Spec
    @within InventorySpecs
    Composed spec: item exists, quantity valid, inventory not full, and category not full.
]=]

--[=[
    @prop CanRemoveItem Spec
    @within InventorySpecs
    Composed spec: slot valid, slot occupied, remove quantity valid, and sufficient quantity.
]=]

--[=[
    @prop CanTransferItem Spec
    @within InventorySpecs
    Composed spec: source and destination differ, from-slot valid, from-slot occupied, and to-slot valid.
]=]

--[=[
    @prop CanStackItem Spec
    @within InventorySpecs
    Composed spec: item exists and item is marked stackable.
]=]

return table.freeze({
	CanAddItem      = AddItemExists:And(Spec.All({ AddQuantityValid, InventoryNotFull, CategoryNotFull })),
	CanRemoveItem   = SlotValid:And(Spec.All({ SlotOccupied, RemoveQuantityValid, SufficientQuantity })),
	CanTransferItem = NotSameSlot:And(Spec.All({ FromSlotValid, FromSlotOccupied, ToSlotValid })),
	CanStackItem    = StackItemExists:And(ItemStackable),
})
