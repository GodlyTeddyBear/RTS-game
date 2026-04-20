--!strict
local ItemId = require(script.Parent.Parent.Parent.Types.ItemId)
local Rarity = require(script.Parent.Parent.Parent.Types.Rarity)
local Category = require(script.Parent.Parent.Parent.Types.Category)
local ItemData = require(script.Parent.Parent.Parent.Types.ItemData)
local ShopItemUnlock = require(script.Parent.Parent.ShopItemUnlock)

local slice: { [string]: ItemData.ItemData } = {
	-- Equipment - Accessories
	[ItemId.LuckyRing] = {
		id = ItemId.LuckyRing,
		name = "Lucky Ring",
		description = "A ring said to bring fortune to its wearer.",
		icon = "rbxassetid://0",
		rarity = Rarity.Uncommon,
		category = Category.Accessory,
		stats = { LCK = 5 },
		stackable = false,
		maxStack = 1,
		BuyPrice = 90,
		SellPrice = 45,
		Unlock = ShopItemUnlock.futureLockedUnlock(),
	},

	[ItemId.HealthAmulet] = {
		id = ItemId.HealthAmulet,
		name = "Health Amulet",
		description = "An amulet imbued with restorative energy.",
		icon = "rbxassetid://0",
		rarity = Rarity.Uncommon,
		category = Category.Accessory,
		stats = { HP = 15 },
		stackable = false,
		maxStack = 1,
		BuyPrice = 85,
		SellPrice = 42,
		Unlock = ShopItemUnlock.futureLockedUnlock(),
	},

	[ItemId.SpeedBoots] = {
		id = ItemId.SpeedBoots,
		name = "Speed Boots",
		description = "Lightweight boots enchanted for swift movement.",
		icon = "rbxassetid://0",
		rarity = Rarity.Uncommon,
		category = Category.Accessory,
		stats = { SPD = 6 },
		stackable = false,
		maxStack = 1,
		BuyPrice = 95,
		SellPrice = 47,
		Unlock = ShopItemUnlock.futureLockedUnlock(),
	},

	[ItemId.StrengthGauntlet] = {
		id = ItemId.StrengthGauntlet,
		name = "Strength Gauntlet",
		description = "Iron gauntlets that amplify the wearer's striking power.",
		icon = "rbxassetid://0",
		rarity = Rarity.Rare,
		category = Category.Accessory,
		stats = { STR = 6 },
		stackable = false,
		maxStack = 1,
		BuyPrice = 110,
		SellPrice = 55,
		Unlock = ShopItemUnlock.futureLockedUnlock(),
	},

	-- New Accessories
	[ItemId.DefenseAmulet] = {
		id = ItemId.DefenseAmulet,
		name = "Defense Amulet",
		description = "An amulet inscribed with protective runes.",
		icon = "rbxassetid://0",
		rarity = Rarity.Uncommon,
		category = Category.Accessory,
		stats = { DEF = 5 },
		stackable = false,
		maxStack = 1,
		BuyPrice = 85,
		SellPrice = 42,
		Unlock = ShopItemUnlock.futureLockedUnlock(),
	},

	[ItemId.MagicRing] = {
		id = ItemId.MagicRing,
		name = "Magic Ring",
		description = "A ring that channels arcane power through its wearer.",
		icon = "rbxassetid://0",
		rarity = Rarity.Rare,
		category = Category.Accessory,
		stats = { STR = 4, LCK = 3 },
		stackable = false,
		maxStack = 1,
		BuyPrice = 120,
		SellPrice = 60,
		Unlock = ShopItemUnlock.futureLockedUnlock(),
	},

	[ItemId.CrystalPendant] = {
		id = ItemId.CrystalPendant,
		name = "Crystal Pendant",
		description = "A pendant housing a miniature crystal that hums with power.",
		icon = "rbxassetid://0",
		rarity = Rarity.Epic,
		category = Category.Accessory,
		stats = { STR = 5, DEF = 5, HP = 10 },
		stackable = false,
		maxStack = 1,
		BuyPrice = 200,
		SellPrice = 100,
		Unlock = ShopItemUnlock.futureLockedUnlock(),
	},
}

return slice

