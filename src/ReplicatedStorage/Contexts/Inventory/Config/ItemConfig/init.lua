--!strict

local Category = require(script.Parent.Parent.Types.Category)
local ItemData = require(script.Parent.Parent.Types.ItemData)
local ItemId = require(script.Parent.Parent.Types.ItemId)
local Rarity = require(script.Parent.Parent.Types.Rarity)

local ItemConfig: { [string]: ItemData.ItemData } = {
	[ItemId.Scrap] = {
		id = ItemId.Scrap,
		name = "Scrap",
		description = "Recovered battlefield material used for basic upgrades and repairs.",
		icon = "rbxassetid://0",
		rarity = Rarity.Common,
		category = Category.Material,
		stackable = true,
		maxStack = 100,
	},
	[ItemId.Alloy] = {
		id = ItemId.Alloy,
		name = "Alloy",
		description = "Reinforced metal stock used for durable structure components.",
		icon = "rbxassetid://0",
		rarity = Rarity.Uncommon,
		category = Category.Material,
		stackable = true,
		maxStack = 100,
	},
	[ItemId.Circuit] = {
		id = ItemId.Circuit,
		name = "Circuit",
		description = "Recovered control circuitry used in advanced construction.",
		icon = "rbxassetid://0",
		rarity = Rarity.Rare,
		category = Category.Material,
		stackable = true,
		maxStack = 100,
	},
	[ItemId.PowerCore] = {
		id = ItemId.PowerCore,
		name = "Power Core",
		description = "A compact energy core salvaged from elite hostile machines.",
		icon = "rbxassetid://0",
		rarity = Rarity.Epic,
		category = Category.Material,
		stackable = true,
		maxStack = 25,
	},
	[ItemId.RelicShard] = {
		id = ItemId.RelicShard,
		name = "Relic Shard",
		description = "A rare fragment used for future commander and base progression.",
		icon = "rbxassetid://0",
		rarity = Rarity.Legendary,
		category = Category.Material,
		stackable = true,
		maxStack = 10,
	},
}

return table.freeze(ItemConfig)
