--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Spec = require(ReplicatedStorage.Utilities.Specification)
local Errors = require(script.Parent.Parent.Parent.Errors)

export type TAddItemCandidate = {
	ItemExists: boolean,
	AddQuantityValid: boolean,
	InventoryNotFull: boolean,
}

export type TRemoveItemCandidate = {
	SlotValid: boolean,
	SlotOccupied: boolean,
	RemoveQuantityValid: boolean,
	SufficientQuantity: boolean,
}

local AddItemExists = Spec.new("InvalidItemId", Errors.INVALID_ITEM_ID, function(ctx: TAddItemCandidate)
	return ctx.ItemExists
end)

local AddQuantityValid = Spec.new("InvalidQuantity", Errors.INVALID_QUANTITY, function(ctx: TAddItemCandidate)
	return ctx.AddQuantityValid
end)

local InventoryNotFull = Spec.new("InventoryFull", Errors.INVENTORY_FULL, function(ctx: TAddItemCandidate)
	return ctx.InventoryNotFull
end)

local SlotValid = Spec.new("InvalidSlotIndex", Errors.INVALID_SLOT_INDEX, function(ctx: TRemoveItemCandidate)
	return ctx.SlotValid
end)

local SlotOccupied = Spec.new("SlotEmpty", Errors.SLOT_EMPTY, function(ctx: TRemoveItemCandidate)
	return ctx.SlotOccupied
end)

local RemoveQuantityValid = Spec.new("InvalidQuantity", Errors.INVALID_QUANTITY, function(ctx: TRemoveItemCandidate)
	return ctx.RemoveQuantityValid
end)

local SufficientQuantity = Spec.new("InsufficientQuantity", Errors.INSUFFICIENT_QUANTITY, function(ctx: TRemoveItemCandidate)
	return ctx.SufficientQuantity
end)

return table.freeze({
	CanAddItem = AddItemExists:And(Spec.All({ AddQuantityValid, InventoryNotFull })),
	CanRemoveItem = SlotValid:And(Spec.All({ SlotOccupied, RemoveQuantityValid, SufficientQuantity })),
})
