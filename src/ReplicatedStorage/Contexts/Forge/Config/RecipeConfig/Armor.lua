--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RecipeId = require(script.Parent.Parent.Parent.Types.RecipeId)
local ItemId = require(ReplicatedStorage.Contexts.Inventory.Types.ItemId)

local Armor: { [string]: any } = {
	-- Basic Tier
	[RecipeId.IronArmor] = {
		Id = RecipeId.IronArmor,
		Name = "Iron Armor",
		Description = "Heavy armor crafted from iron ore.",
		Icon = "rbxassetid://0",
		OutputItemId = ItemId.IronArmor,
		OutputQuantity = 1,
		Ingredients = {
			{ ItemId = ItemId.IronOre, Quantity = 8 },
		},
		IsAutomatable = true,
		ForgeStation = "Anvil",
	},

	[RecipeId.LeatherArmor] = {
		Id = RecipeId.LeatherArmor,
		Name = "Leather Armor",
		Description = "Light armor reinforced with stone.",
		Icon = "rbxassetid://0",
		OutputItemId = ItemId.LeatherArmor,
		OutputQuantity = 1,
		Ingredients = {
			{ ItemId = ItemId.Stone, Quantity = 5 },
		},
		IsAutomatable = true,
		ForgeStation = "WorkBench",
	},

	-- Steel Tier
	[RecipeId.SteelArmor] = {
		Id = RecipeId.SteelArmor,
		Name = "Steel Armor",
		Description = "Heavy plate armor forged from tempered steel.",
		Icon = "rbxassetid://0",
		OutputItemId = ItemId.SteelArmor,
		OutputQuantity = 1,
		Ingredients = {
			{ ItemId = ItemId.IronPlate, Quantity = 5 },
			{ ItemId = ItemId.Coal, Quantity = 3 },
		},
		IsAutomatable = true,
		QualityUpgrades = {
			Rare = ItemId.SteelArmor,
		},
		ForgeStation = "Anvil",
	},

	-- Specialized
	[RecipeId.MageRobe] = {
		Id = RecipeId.MageRobe,
		Name = "Mage Robe",
		Description = "Enchanted robes woven with arcane thread.",
		Icon = "rbxassetid://0",
		OutputItemId = ItemId.MageRobe,
		OutputQuantity = 1,
		Ingredients = {
			{ ItemId = ItemId.CopperPlate, Quantity = 3 },
			{ ItemId = ItemId.Stone, Quantity = 2 },
		},
		IsAutomatable = true,
		ForgeStation = "WorkBench",
	},

	[RecipeId.RogueCloak] = {
		Id = RecipeId.RogueCloak,
		Name = "Rogue Cloak",
		Description = "A lightweight cloak favoring agility over protection.",
		Icon = "rbxassetid://0",
		OutputItemId = ItemId.RogueCloak,
		OutputQuantity = 1,
		Ingredients = {
			{ ItemId = ItemId.LeatherArmor, Quantity = 1 },
			{ ItemId = ItemId.CopperPlate, Quantity = 2 },
		},
		IsAutomatable = true,
		ForgeStation = "WorkBench",
	},

	[RecipeId.SilkRobe] = {
		Id = RecipeId.SilkRobe,
		Name = "Silk Robe",
		Description = "An elegant robe woven from enchanted silk.",
		Icon = "rbxassetid://0",
		OutputItemId = ItemId.SilkRobe,
		OutputQuantity = 1,
		Ingredients = {
			{ ItemId = ItemId.Silk, Quantity = 5 },
			{ ItemId = ItemId.Crystal, Quantity = 1 },
		},
		IsAutomatable = true,
		ForgeStation = "WorkBench",
	},

	[RecipeId.GuardianShield] = {
		Id = RecipeId.GuardianShield,
		Name = "Guardian Shield",
		Description = "A tower shield built to protect the entire party.",
		Icon = "rbxassetid://0",
		OutputItemId = ItemId.GuardianShield,
		OutputQuantity = 1,
		Ingredients = {
			{ ItemId = ItemId.SteelPlate, Quantity = 4 },
			{ ItemId = ItemId.IronPlate, Quantity = 2 },
		},
		IsAutomatable = true,
		ForgeStation = "Anvil",
	},

	-- Gold & Crystal Tier
	[RecipeId.GoldArmor] = {
		Id = RecipeId.GoldArmor,
		Name = "Gold Armor",
		Description = "Ornate armor plated with gold over a steel core.",
		Icon = "rbxassetid://0",
		OutputItemId = ItemId.GoldArmor,
		OutputQuantity = 1,
		Ingredients = {
			{ ItemId = ItemId.GoldPlate, Quantity = 5 },
			{ ItemId = ItemId.SteelPlate, Quantity = 3 },
		},
		IsAutomatable = true,
		ForgeStation = "Anvil",
	},

	[RecipeId.DragonArmor] = {
		Id = RecipeId.DragonArmor,
		Name = "Dragon Armor",
		Description = "Legendary armor forged from dragon scales. Nearly indestructible.",
		Icon = "rbxassetid://0",
		OutputItemId = ItemId.DragonArmor,
		OutputQuantity = 1,
		Ingredients = {
			{ ItemId = ItemId.DragonScale, Quantity = 5 },
			{ ItemId = ItemId.GoldPlate, Quantity = 3 },
			{ ItemId = ItemId.Crystal, Quantity = 2 },
		},
		IsAutomatable = false,
		ForgeStation = "Anvil",
	},
}

return Armor
