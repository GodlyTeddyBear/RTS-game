--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RecipeId = require(script.Parent.Parent.Parent.Types.RecipeId)
local ItemId = require(ReplicatedStorage.Contexts.Inventory.Types.ItemId)

local Accessories: { [string]: any } = {
	[RecipeId.LuckyRing] = {
		Id = RecipeId.LuckyRing,
		Name = "Lucky Ring",
		Description = "A ring said to bring fortune to its wearer.",
		Icon = "rbxassetid://0",
		OutputItemId = ItemId.LuckyRing,
		OutputQuantity = 1,
		Ingredients = {
			{ ItemId = ItemId.GoldOre, Quantity = 3 },
			{ ItemId = ItemId.CopperPlate, Quantity = 2 },
		},
		IsAutomatable = true,
		ForgeStation = "Anvil",
	},

	[RecipeId.HealthAmulet] = {
		Id = RecipeId.HealthAmulet,
		Name = "Health Amulet",
		Description = "An amulet imbued with restorative energy.",
		Icon = "rbxassetid://0",
		OutputItemId = ItemId.HealthAmulet,
		OutputQuantity = 1,
		Ingredients = {
			{ ItemId = ItemId.GoldOre, Quantity = 2 },
			{ ItemId = ItemId.Herb, Quantity = 4 },
		},
		IsAutomatable = true,
		ForgeStation = "WorkBench",
	},

	[RecipeId.SpeedBoots] = {
		Id = RecipeId.SpeedBoots,
		Name = "Speed Boots",
		Description = "Lightweight boots enchanted for swift movement.",
		Icon = "rbxassetid://0",
		OutputItemId = ItemId.SpeedBoots,
		OutputQuantity = 1,
		Ingredients = {
			{ ItemId = ItemId.LeatherArmor, Quantity = 1 },
			{ ItemId = ItemId.Silk, Quantity = 3 },
		},
		IsAutomatable = true,
		ForgeStation = "WorkBench",
	},

	[RecipeId.StrengthGauntlet] = {
		Id = RecipeId.StrengthGauntlet,
		Name = "Strength Gauntlet",
		Description = "Iron gauntlets that amplify the wearer's striking power.",
		Icon = "rbxassetid://0",
		OutputItemId = ItemId.StrengthGauntlet,
		OutputQuantity = 1,
		Ingredients = {
			{ ItemId = ItemId.SteelPlate, Quantity = 2 },
			{ ItemId = ItemId.IronPlate, Quantity = 2 },
		},
		IsAutomatable = true,
		ForgeStation = "Anvil",
	},

	[RecipeId.DefenseAmulet] = {
		Id = RecipeId.DefenseAmulet,
		Name = "Defense Amulet",
		Description = "An amulet inscribed with protective runes.",
		Icon = "rbxassetid://0",
		OutputItemId = ItemId.DefenseAmulet,
		OutputQuantity = 1,
		Ingredients = {
			{ ItemId = ItemId.Stone, Quantity = 5 },
			{ ItemId = ItemId.GoldOre, Quantity = 2 },
		},
		IsAutomatable = true,
		ForgeStation = "WorkBench",
	},

	[RecipeId.MagicRing] = {
		Id = RecipeId.MagicRing,
		Name = "Magic Ring",
		Description = "A ring that channels arcane power through its wearer.",
		Icon = "rbxassetid://0",
		OutputItemId = ItemId.MagicRing,
		OutputQuantity = 1,
		Ingredients = {
			{ ItemId = ItemId.GoldPlate, Quantity = 1 },
			{ ItemId = ItemId.Crystal, Quantity = 2 },
		},
		IsAutomatable = true,
		ForgeStation = "WorkBench",
	},

	[RecipeId.CrystalPendant] = {
		Id = RecipeId.CrystalPendant,
		Name = "Crystal Pendant",
		Description = "A pendant housing a miniature crystal that hums with power.",
		Icon = "rbxassetid://0",
		OutputItemId = ItemId.CrystalPendant,
		OutputQuantity = 1,
		Ingredients = {
			{ ItemId = ItemId.Crystal, Quantity = 3 },
			{ ItemId = ItemId.GoldPlate, Quantity = 2 },
			{ ItemId = ItemId.Silk, Quantity = 1 },
		},
		IsAutomatable = true,
		ForgeStation = "WorkBench",
	},
}

return Accessories
