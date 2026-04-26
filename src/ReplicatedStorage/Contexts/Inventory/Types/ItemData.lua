--!strict

local Category = require(script.Parent.Category)
local ItemId = require(script.Parent.ItemId)
local Rarity = require(script.Parent.Rarity)

export type ItemData = {
	id: ItemId.ItemId,
	name: string,
	description: string,
	icon: string,
	rarity: Rarity.Rarity,
	category: Category.Category,
	stackable: boolean,
	maxStack: number,
}

return {}
