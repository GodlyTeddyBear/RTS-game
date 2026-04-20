--!strict
local ItemId = require(script.Parent.ItemId)
local Rarity = require(script.Parent.Rarity)
local ItemStats = require(script.Parent.ItemStats)
local Category = require(script.Parent.Category)

export type ItemData = {
	id: ItemId.ItemId,
	name: string,
	description: string,
	icon: string,
	rarity: Rarity.Rarity,
	category: Category.Category,
	stats: ItemStats.ItemStats?,
	stackable: boolean,
	maxStack: number,
	BuyPrice: number?,
	SellPrice: number?,
	WeaponType: string?,
}

export type InventoryItem = {
	itemId: ItemId.ItemId,
	quantity: number,
	slotIndex: number,
}

return {}
