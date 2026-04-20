--!strict
local ItemId = require(script.Parent.Parent.Types.ItemId)
local Rarity = require(script.Parent.Parent.Types.Rarity)
local Category = require(script.Parent.Parent.Types.Category)
local ItemData = require(script.Parent.Parent.Types.ItemData)

local ItemConfig: { [string]: ItemData.ItemData } = {
	[ItemId.IronOre] = {
		id = ItemId.IronOre,
		name = "Iron Ore",
		description = "Raw iron ore extracted from mines. Can be smelted into iron plates.",
		icon = "rbxassetid://0",
		rarity = Rarity.Common,
		category = Category.Material,
		stats = nil,
		stackable = true,
		maxStack = 100,
		BuyPrice = 15,
		SellPrice = 7,
	},

	[ItemId.CopperOre] = {
		id = ItemId.CopperOre,
		name = "Copper Ore",
		description = "Raw copper ore. Essential for crafting electronic components.",
		icon = "rbxassetid://0",
		rarity = Rarity.Common,
		category = Category.Material,
		stats = nil,
		stackable = true,
		maxStack = 100,
		BuyPrice = 15,
		SellPrice = 7,
	},

	[ItemId.Stone] = {
		id = ItemId.Stone,
		name = "Stone",
		description = "Basic stone material. Common and versatile for construction.",
		icon = "rbxassetid://0",
		rarity = Rarity.Common,
		category = Category.Material,
		stats = nil,
		stackable = true,
		maxStack = 100,
		BuyPrice = 10,
		SellPrice = 5,
	},

	[ItemId.None] = {
		id = ItemId.None,
		name = "Empty Slot",
		description = "An empty inventory slot.",
		icon = "rbxassetid://0",
		rarity = Rarity.Common,
		category = Category.Material,
		stats = nil,
		stackable = false,
		maxStack = 0,
		BuyPrice = nil,
		SellPrice = nil,
	},
}

table.freeze(ItemConfig)
return ItemConfig
