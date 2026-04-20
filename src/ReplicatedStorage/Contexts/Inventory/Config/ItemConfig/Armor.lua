--!strict
local ItemId = require(script.Parent.Parent.Parent.Types.ItemId)
local Rarity = require(script.Parent.Parent.Parent.Types.Rarity)
local Category = require(script.Parent.Parent.Parent.Types.Category)
local ItemData = require(script.Parent.Parent.Parent.Types.ItemData)
local ShopItemUnlock = require(script.Parent.Parent.ShopItemUnlock)

local slice: { [string]: ItemData.ItemData } = {
	[ItemId.IronArmor] = {
		id = ItemId.IronArmor,
		name = "Iron Armor",
		description = "Heavy armor crafted from iron ore.",
		icon = "rbxassetid://0",
		rarity = Rarity.Uncommon,
		category = Category.Armor,
		stats = { DEF = 8 },
		stackable = false,
		maxStack = 1,
		BuyPrice = 80,
		SellPrice = 40,
		Unlock = ShopItemUnlock.chapter2IronGearUnlock(),
	},

	[ItemId.LeatherArmor] = {
		id = ItemId.LeatherArmor,
		name = "Leather Armor",
		description = "Light armor reinforced with stone.",
		icon = "rbxassetid://0",
		rarity = Rarity.Common,
		category = Category.Armor,
		stats = { DEF = 3 },
		stackable = false,
		maxStack = 1,
		BuyPrice = 40,
		SellPrice = 20,
		Unlock = ShopItemUnlock.futureLockedUnlock(),
	},

	-- Equipment - Armor
	[ItemId.SteelArmor] = {
		id = ItemId.SteelArmor,
		name = "Steel Armor",
		description = "Heavy plate armor forged from tempered steel.",
		icon = "rbxassetid://0",
		rarity = Rarity.Rare,
		category = Category.Armor,
		stats = { DEF = 14 },
		stackable = false,
		maxStack = 1,
		BuyPrice = 200,
		SellPrice = 100,
		Unlock = ShopItemUnlock.futureLockedUnlock(),
	},

	[ItemId.MageRobe] = {
		id = ItemId.MageRobe,
		name = "Mage Robe",
		description = "Enchanted robes woven with arcane thread.",
		icon = "rbxassetid://0",
		rarity = Rarity.Uncommon,
		category = Category.Armor,
		stats = { DEF = 4, STR = 3 },
		stackable = false,
		maxStack = 1,
		BuyPrice = 70,
		SellPrice = 35,
		Unlock = ShopItemUnlock.futureLockedUnlock(),
	},

	[ItemId.RogueCloak] = {
		id = ItemId.RogueCloak,
		name = "Rogue Cloak",
		description = "A lightweight cloak favoring agility over protection.",
		icon = "rbxassetid://0",
		rarity = Rarity.Uncommon,
		category = Category.Armor,
		stats = { DEF = 3, SPD = 4 },
		stackable = false,
		maxStack = 1,
		BuyPrice = 65,
		SellPrice = 32,
		Unlock = ShopItemUnlock.futureLockedUnlock(),
	},

	-- Gold Tier & Dragon Tier Armor
	[ItemId.GoldArmor] = {
		id = ItemId.GoldArmor,
		name = "Gold Armor",
		description = "Ornate armor plated with gold over a steel core.",
		icon = "rbxassetid://0",
		rarity = Rarity.Epic,
		category = Category.Armor,
		stats = { DEF = 18 },
		stackable = false,
		maxStack = 1,
		BuyPrice = 350,
		SellPrice = 175,
		Unlock = ShopItemUnlock.futureLockedUnlock(),
	},

	[ItemId.DragonArmor] = {
		id = ItemId.DragonArmor,
		name = "Dragon Armor",
		description = "Legendary armor forged from dragon scales. Nearly indestructible.",
		icon = "rbxassetid://0",
		rarity = Rarity.Legendary,
		category = Category.Armor,
		stats = { DEF = 25, HP = 20 },
		stackable = false,
		maxStack = 1,
		BuyPrice = 600,
		SellPrice = 300,
		Unlock = ShopItemUnlock.futureLockedUnlock(),
	},

	[ItemId.SilkRobe] = {
		id = ItemId.SilkRobe,
		name = "Silk Robe",
		description = "An elegant robe woven from enchanted silk.",
		icon = "rbxassetid://0",
		rarity = Rarity.Rare,
		category = Category.Armor,
		stats = { DEF = 6, STR = 5, SPD = 2 },
		stackable = false,
		maxStack = 1,
		BuyPrice = 130,
		SellPrice = 65,
		Unlock = ShopItemUnlock.futureLockedUnlock(),
	},

	[ItemId.GuardianShield] = {
		id = ItemId.GuardianShield,
		name = "Guardian Shield",
		description = "A tower shield built to protect the entire party.",
		icon = "rbxassetid://0",
		rarity = Rarity.Rare,
		category = Category.Armor,
		stats = { DEF = 12, HP = 10 },
		stackable = false,
		maxStack = 1,
		BuyPrice = 160,
		SellPrice = 80,
		Unlock = ShopItemUnlock.futureLockedUnlock(),
	},
}

return slice

