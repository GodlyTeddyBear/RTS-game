--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Spec = require(ReplicatedStorage.Utilities.Specification)
local Errors = require(script.Parent.Parent.Parent.Errors)

export type TEquipCandidate = {
	ItemConfigured: boolean,
	SlotConfigured: boolean,
	SlotMatchesItem: boolean,
	SlotAvailable: boolean,
	ItemOwned: boolean,
	OwnerResolved: boolean,
}

export type TUnequipCandidate = {
	SlotOccupied: boolean,
}

local ItemConfigured = Spec.new("InvalidItemId", Errors.INVALID_ITEM_ID, function(ctx: TEquipCandidate)
	return ctx.ItemConfigured
end)

local SlotConfigured = Spec.new("InvalidSlotId", Errors.INVALID_SLOT_ID, function(ctx: TEquipCandidate)
	return ctx.SlotConfigured
end)

local SlotMatchesItem = Spec.new("SlotMismatch", Errors.SLOT_MISMATCH, function(ctx: TEquipCandidate)
	return ctx.SlotMatchesItem
end)

local SlotAvailable = Spec.new("SlotOccupied", Errors.SLOT_OCCUPIED, function(ctx: TEquipCandidate)
	return ctx.SlotAvailable
end)

local ItemOwned = Spec.new("ItemNotOwned", Errors.ITEM_NOT_OWNED, function(ctx: TEquipCandidate)
	return ctx.ItemOwned
end)

local OwnerResolved = Spec.new("OwnerNotFound", Errors.OWNER_NOT_FOUND, function(ctx: TEquipCandidate)
	return ctx.OwnerResolved
end)

local UnequipSlotOccupied = Spec.new("SlotEmpty", Errors.SLOT_EMPTY, function(ctx: TUnequipCandidate)
	return ctx.SlotOccupied
end)

return table.freeze({
	CanEquip = Spec.All({
		ItemConfigured,
		SlotConfigured,
		SlotMatchesItem,
		SlotAvailable,
		ItemOwned,
		OwnerResolved,
	}),
	CanUnequip = UnequipSlotOccupied,
})
