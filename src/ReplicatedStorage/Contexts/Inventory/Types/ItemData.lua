--!strict

local Category = require(script.Parent.Category)
local ItemId = require(script.Parent.ItemId)
local Rarity = require(script.Parent.Rarity)

export type ItemData = {
	Id: ItemId.ItemId,
	Name: string,
	Description: string,
	Icon: string,
	Rarity: Rarity.Rarity,
	Category: Category.Category,
	Stackable: boolean,
	MaxStack: number,
}

return {}
