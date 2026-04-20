--!strict
local ItemId = require(script.Parent.Parent.Parent.Types.ItemId)
local Rarity = require(script.Parent.Parent.Parent.Types.Rarity)
local Category = require(script.Parent.Parent.Parent.Types.Category)
local ItemData = require(script.Parent.Parent.Parent.Types.ItemData)

local slice: { [string]: ItemData.ItemData } = {
	-- Cosmetics
	[ItemId.GoldenCrown] = {
		id = ItemId.GoldenCrown,
		name = "Golden Crown",
		description = "A regal crown signifying mastery of the forge.",
		icon = "rbxassetid://0",
		rarity = Rarity.Legendary,
		category = Category.Cosmetic,
		stats = nil,
		stackable = false,
		maxStack = 1,
		BuyPrice = nil,
		SellPrice = 500,
	},

	[ItemId.ShadowCloak] = {
		id = ItemId.ShadowCloak,
		name = "Shadow Cloak",
		description = "A dark cloak that wraps the wearer in living shadow.",
		icon = "rbxassetid://0",
		rarity = Rarity.Legendary,
		category = Category.Cosmetic,
		stats = nil,
		stackable = false,
		maxStack = 1,
		BuyPrice = nil,
		SellPrice = 500,
	},

	[ItemId.CrystalWings] = {
		id = ItemId.CrystalWings,
		name = "Crystal Wings",
		description = "Ethereal wings formed from pure crystallized energy.",
		icon = "rbxassetid://0",
		rarity = Rarity.Legendary,
		category = Category.Cosmetic,
		stats = nil,
		stackable = false,
		maxStack = 1,
		BuyPrice = nil,
		SellPrice = 500,
	},
}

return slice
