--!strict

local Category = require(script.Parent.Parent.Parent.Types.Category)
local ItemData = require(script.Parent.Parent.Parent.Types.ItemData)
local ItemId = require(script.Parent.Parent.Parent.Types.ItemId)
local Rarity = require(script.Parent.Parent.Parent.Types.Rarity)

local Materials: { [string]: ItemData.ItemData } = {
	[ItemId.Scrap] = {
		Id = ItemId.Scrap,
		Name = "Scrap",
		Description = "Recovered battlefield material used for basic upgrades and repairs.",
		Icon = "rbxassetid://0",
		Rarity = Rarity.Common,
		Category = Category.Material,
		Stackable = true,
		MaxStack = 100,
	},
	[ItemId.Alloy] = {
		Id = ItemId.Alloy,
		Name = "Alloy",
		Description = "Reinforced metal stock used for durable structure components.",
		Icon = "rbxassetid://0",
		Rarity = Rarity.Uncommon,
		Category = Category.Material,
		Stackable = true,
		MaxStack = 100,
	},
	[ItemId.Circuit] = {
		Id = ItemId.Circuit,
		Name = "Circuit",
		Description = "Recovered control circuitry used in advanced construction.",
		Icon = "rbxassetid://0",
		Rarity = Rarity.Rare,
		Category = Category.Material,
		Stackable = true,
		MaxStack = 100,
	},
	[ItemId.PowerCore] = {
		Id = ItemId.PowerCore,
		Name = "Power Core",
		Description = "A compact energy core salvaged from elite hostile machines.",
		Icon = "rbxassetid://0",
		Rarity = Rarity.Epic,
		Category = Category.Material,
		Stackable = true,
		MaxStack = 25,
	},
	[ItemId.RelicShard] = {
		Id = ItemId.RelicShard,
		Name = "Relic Shard",
		Description = "A rare fragment used for future commander and base progression.",
		Icon = "rbxassetid://0",
		Rarity = Rarity.Legendary,
		Category = Category.Material,
		Stackable = true,
		MaxStack = 10,
	},
}

return table.freeze(Materials)
