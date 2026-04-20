--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RecipeId = require(script.Parent.Parent.Parent.Types.RecipeId)
local ItemId = require(ReplicatedStorage.Contexts.Inventory.Types.ItemId)

local Weapons: { [string]: any } = {
	-- Basic Tier
	[RecipeId.IronSword] = {
		Id = RecipeId.IronSword,
		Name = "Iron Sword",
		Description = "A sturdy sword forged from iron ore.",
		Icon = "rbxassetid://0",
		OutputItemId = ItemId.IronSword,
		OutputQuantity = 1,
		Ingredients = {
			{ ItemId = ItemId.IronOre, Quantity = 5 },
		},
		IsAutomatable = true,
		QualityUpgrades = {
			Rare = ItemId.SteelSword,
		},
		ForgeStation = "Anvil",
	},

	[RecipeId.Dagger] = {
		Id = RecipeId.Dagger,
		Name = "Dagger",
		Description = "A quick blade favoring speed over reach.",
		Icon = "rbxassetid://0",
		OutputItemId = ItemId.Dagger,
		OutputQuantity = 1,
		Ingredients = {
			{ ItemId = ItemId.CopperPlate, Quantity = 2 },
			{ ItemId = ItemId.Stone, Quantity = 1 },
		},
		IsAutomatable = true,
		ForgeStation = "Anvil",
	},

	[RecipeId.MagicStaff] = {
		Id = RecipeId.MagicStaff,
		Name = "Magic Staff",
		Description = "A staff imbued with arcane energy for ranged attacks.",
		Icon = "rbxassetid://0",
		OutputItemId = ItemId.MagicStaff,
		OutputQuantity = 1,
		Ingredients = {
			{ ItemId = ItemId.IronPlate, Quantity = 2 },
			{ ItemId = ItemId.CopperPlate, Quantity = 3 },
		},
		IsAutomatable = true,
		ForgeStation = "Anvil",
	},

	-- Steel Tier
	[RecipeId.SteelSword] = {
		Id = RecipeId.SteelSword,
		Name = "Steel Sword",
		Description = "A finely crafted sword of tempered steel.",
		Icon = "rbxassetid://0",
		OutputItemId = ItemId.SteelSword,
		OutputQuantity = 1,
		Ingredients = {
			{ ItemId = ItemId.IronPlate, Quantity = 3 },
			{ ItemId = ItemId.Coal, Quantity = 2 },
		},
		IsAutomatable = true,
		ForgeStation = "Anvil",
	},

	[RecipeId.SteelDagger] = {
		Id = RecipeId.SteelDagger,
		Name = "Steel Dagger",
		Description = "A razor-sharp dagger of tempered steel.",
		Icon = "rbxassetid://0",
		OutputItemId = ItemId.SteelDagger,
		OutputQuantity = 1,
		Ingredients = {
			{ ItemId = ItemId.SteelPlate, Quantity = 1 },
			{ ItemId = ItemId.CopperPlate, Quantity = 1 },
		},
		IsAutomatable = true,
		ForgeStation = "Anvil",
	},

	[RecipeId.Longbow] = {
		Id = RecipeId.Longbow,
		Name = "Longbow",
		Description = "A sturdy bow crafted for long-range precision.",
		Icon = "rbxassetid://0",
		OutputItemId = ItemId.Longbow,
		OutputQuantity = 1,
		Ingredients = {
			{ ItemId = ItemId.IronPlate, Quantity = 2 },
			{ ItemId = ItemId.Silk, Quantity = 3 },
		},
		IsAutomatable = true,
		ForgeStation = "Anvil",
	},

	[RecipeId.Warhammer] = {
		Id = RecipeId.Warhammer,
		Name = "Warhammer",
		Description = "A massive hammer that trades speed for devastating force.",
		Icon = "rbxassetid://0",
		OutputItemId = ItemId.Warhammer,
		OutputQuantity = 1,
		Ingredients = {
			{ ItemId = ItemId.SteelPlate, Quantity = 3 },
			{ ItemId = ItemId.Stone, Quantity = 5 },
		},
		IsAutomatable = true,
		ForgeStation = "Anvil",
	},

	-- Gold & Crystal Tier
	[RecipeId.GoldSword] = {
		Id = RecipeId.GoldSword,
		Name = "Gold Sword",
		Description = "An ornate blade forged from pure gold and steel.",
		Icon = "rbxassetid://0",
		OutputItemId = ItemId.GoldSword,
		OutputQuantity = 1,
		Ingredients = {
			{ ItemId = ItemId.GoldPlate, Quantity = 3 },
			{ ItemId = ItemId.SteelPlate, Quantity = 2 },
		},
		IsAutomatable = true,
		ForgeStation = "Anvil",
	},

	[RecipeId.CrystalStaff] = {
		Id = RecipeId.CrystalStaff,
		Name = "Crystal Staff",
		Description = "A staff crowned with a focused crystal, amplifying magical power.",
		Icon = "rbxassetid://0",
		OutputItemId = ItemId.CrystalStaff,
		OutputQuantity = 1,
		Ingredients = {
			{ ItemId = ItemId.Crystal, Quantity = 3 },
			{ ItemId = ItemId.GoldPlate, Quantity = 2 },
		},
		IsAutomatable = true,
		ForgeStation = "Anvil",
	},
}

return Weapons
