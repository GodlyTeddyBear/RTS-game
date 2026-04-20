--!strict
local ItemId = require(script.Parent.Parent.Parent.Types.ItemId)
local Rarity = require(script.Parent.Parent.Parent.Types.Rarity)
local Category = require(script.Parent.Parent.Parent.Types.Category)
local ItemData = require(script.Parent.Parent.Parent.Types.ItemData)
local ShopItemUnlock = require(script.Parent.Parent.ShopItemUnlock)

local slice: { [string]: ItemData.ItemData } = {
	-- Consumables
	[ItemId.HealingPotion] = {
		id = ItemId.HealingPotion,
		name = "Healing Potion",
		description = "Restores a moderate amount of health when consumed.",
		icon = "rbxassetid://0",
		rarity = Rarity.Common,
		category = Category.Consumable,
		stats = { HP = 30 },
		stackable = true,
		maxStack = 50,
		BuyPrice = 25,
		SellPrice = 12,
		Unlock = ShopItemUnlock.chapter3StarterPotionUnlock(),
	},

	[ItemId.ManaPotion] = {
		id = ItemId.ManaPotion,
		name = "Mana Potion",
		description = "Restores magical energy to the drinker.",
		icon = "rbxassetid://0",
		rarity = Rarity.Common,
		category = Category.Consumable,
		stats = nil,
		stackable = true,
		maxStack = 50,
		BuyPrice = 25,
		SellPrice = 12,
		Unlock = ShopItemUnlock.chapter3StarterPotionUnlock(),
	},

	[ItemId.Antidote] = {
		id = ItemId.Antidote,
		name = "Antidote",
		description = "Cures poison and other common ailments.",
		icon = "rbxassetid://0",
		rarity = Rarity.Common,
		category = Category.Consumable,
		stats = nil,
		stackable = true,
		maxStack = 50,
		BuyPrice = 20,
		SellPrice = 10,
		Unlock = ShopItemUnlock.chapter3StarterPotionUnlock(),
	},

	[ItemId.StrengthElixir] = {
		id = ItemId.StrengthElixir,
		name = "Strength Elixir",
		description = "Temporarily boosts the drinker's attack power.",
		icon = "rbxassetid://0",
		rarity = Rarity.Uncommon,
		category = Category.Consumable,
		stats = { STR = 8 },
		stackable = true,
		maxStack = 30,
		BuyPrice = 45,
		SellPrice = 22,
		Unlock = ShopItemUnlock.futureLockedUnlock(),
	},

	[ItemId.DefensePotion] = {
		id = ItemId.DefensePotion,
		name = "Defense Potion",
		description = "Temporarily hardens the drinker's skin against attacks.",
		icon = "rbxassetid://0",
		rarity = Rarity.Uncommon,
		category = Category.Consumable,
		stats = { DEF = 8 },
		stackable = true,
		maxStack = 30,
		BuyPrice = 45,
		SellPrice = 22,
		Unlock = ShopItemUnlock.futureLockedUnlock(),
	},

	-- New Consumables
	[ItemId.GreaterHealingPotion] = {
		id = ItemId.GreaterHealingPotion,
		name = "Greater Healing Potion",
		description = "A potent brew that restores a large amount of health.",
		icon = "rbxassetid://0",
		rarity = Rarity.Uncommon,
		category = Category.Consumable,
		stats = { HP = 75 },
		stackable = true,
		maxStack = 30,
		BuyPrice = 60,
		SellPrice = 30,
		Unlock = ShopItemUnlock.futureLockedUnlock(),
	},

	[ItemId.SpeedPotion] = {
		id = ItemId.SpeedPotion,
		name = "Speed Potion",
		description = "Temporarily grants the drinker bursts of incredible speed.",
		icon = "rbxassetid://0",
		rarity = Rarity.Uncommon,
		category = Category.Consumable,
		stats = { SPD = 10 },
		stackable = true,
		maxStack = 30,
		BuyPrice = 45,
		SellPrice = 22,
		Unlock = ShopItemUnlock.futureLockedUnlock(),
	},

	[ItemId.LuckPotion] = {
		id = ItemId.LuckPotion,
		name = "Luck Potion",
		description = "A shimmering golden brew that improves fortune.",
		icon = "rbxassetid://0",
		rarity = Rarity.Rare,
		category = Category.Consumable,
		stats = { LCK = 10 },
		stackable = true,
		maxStack = 20,
		BuyPrice = 80,
		SellPrice = 40,
		Unlock = ShopItemUnlock.futureLockedUnlock(),
	},
}

return slice

