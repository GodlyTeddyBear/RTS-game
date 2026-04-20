--!strict
local BreweryRecipeId = require(script.Parent.Parent.Types.BreweryRecipeId)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ItemId = require(ReplicatedStorage.Contexts.Inventory.Types.ItemId)

export type TBreweryIngredient = {
	ItemId: string,
	Quantity: number,
}

export type TBreweryRecipeData = {
	Id: string,
	Name: string,
	Description: string,
	Icon: string,
	OutputItemId: string,
	OutputQuantity: number,
	Ingredients: { TBreweryIngredient },
	IsAutomatable: boolean,
	BrewStation: string?,
}

local BreweryRecipeConfig: { [string]: TBreweryRecipeData } = {

	-- Basic Potions
	[BreweryRecipeId.HealingBrew] = {
		Id = BreweryRecipeId.HealingBrew,
		Name = "Healing Brew",
		Description = "A simple restorative potion brewed from common herbs.",
		Icon = "rbxassetid://0",
		OutputItemId = ItemId.HealingPotion,
		OutputQuantity = 2,
		Ingredients = {
			{ ItemId = ItemId.Herb, Quantity = 3 },
			{ ItemId = ItemId.Stone, Quantity = 1 },
		},
		IsAutomatable = true,
		BrewStation = "BrewKettle",
	},

	[BreweryRecipeId.ManaBrew] = {
		Id = BreweryRecipeId.ManaBrew,
		Name = "Mana Brew",
		Description = "A crystalline brew that restores magical energy.",
		Icon = "rbxassetid://0",
		OutputItemId = ItemId.ManaPotion,
		OutputQuantity = 2,
		Ingredients = {
			{ ItemId = ItemId.Herb, Quantity = 3 },
			{ ItemId = ItemId.Crystal, Quantity = 1 },
		},
		IsAutomatable = true,
		BrewStation = "BrewKettle",
	},

	[BreweryRecipeId.AntidoteBrew] = {
		Id = BreweryRecipeId.AntidoteBrew,
		Name = "Antidote Brew",
		Description = "A purifying concoction that neutralizes toxins.",
		Icon = "rbxassetid://0",
		OutputItemId = ItemId.Antidote,
		OutputQuantity = 2,
		Ingredients = {
			{ ItemId = ItemId.Herb, Quantity = 4 },
			{ ItemId = ItemId.CopperOre, Quantity = 1 },
		},
		IsAutomatable = true,
		BrewStation = "BrewKettle",
	},

	-- Tonics
	[BreweryRecipeId.StrengthTonic] = {
		Id = BreweryRecipeId.StrengthTonic,
		Name = "Strength Tonic",
		Description = "A potent tonic that amplifies physical power.",
		Icon = "rbxassetid://0",
		OutputItemId = ItemId.StrengthElixir,
		OutputQuantity = 1,
		Ingredients = {
			{ ItemId = ItemId.Herb, Quantity = 4 },
			{ ItemId = ItemId.Crystal, Quantity = 2 },
			{ ItemId = ItemId.Coal, Quantity = 1 },
		},
		IsAutomatable = true,
		BrewStation = "BrewKettle",
	},

	[BreweryRecipeId.DefenseTonic] = {
		Id = BreweryRecipeId.DefenseTonic,
		Name = "Defense Tonic",
		Description = "A fortifying tonic that hardens the body against harm.",
		Icon = "rbxassetid://0",
		OutputItemId = ItemId.DefensePotion,
		OutputQuantity = 1,
		Ingredients = {
			{ ItemId = ItemId.Herb, Quantity = 3 },
			{ ItemId = ItemId.Stone, Quantity = 3 },
			{ ItemId = ItemId.Crystal, Quantity = 1 },
		},
		IsAutomatable = true,
		BrewStation = "BrewKettle",
	},

	[BreweryRecipeId.SpeedTonic] = {
		Id = BreweryRecipeId.SpeedTonic,
		Name = "Speed Tonic",
		Description = "A silken brew that quickens the limbs.",
		Icon = "rbxassetid://0",
		OutputItemId = ItemId.SpeedPotion,
		OutputQuantity = 1,
		Ingredients = {
			{ ItemId = ItemId.Herb, Quantity = 3 },
			{ ItemId = ItemId.Silk, Quantity = 2 },
			{ ItemId = ItemId.Crystal, Quantity = 1 },
		},
		IsAutomatable = true,
		BrewStation = "BrewKettle",
	},

	[BreweryRecipeId.LuckElixir] = {
		Id = BreweryRecipeId.LuckElixir,
		Name = "Luck Elixir",
		Description = "A golden elixir said to attract fortune.",
		Icon = "rbxassetid://0",
		OutputItemId = ItemId.LuckPotion,
		OutputQuantity = 1,
		Ingredients = {
			{ ItemId = ItemId.Herb, Quantity = 3 },
			{ ItemId = ItemId.GoldOre, Quantity = 2 },
			{ ItemId = ItemId.Crystal, Quantity = 1 },
		},
		IsAutomatable = true,
		BrewStation = "BrewKettle",
	},

	-- Greater Potions
	[BreweryRecipeId.GreaterHealingBrew] = {
		Id = BreweryRecipeId.GreaterHealingBrew,
		Name = "Greater Healing Brew",
		Description = "A powerful restorative potion for serious wounds.",
		Icon = "rbxassetid://0",
		OutputItemId = ItemId.GreaterHealingPotion,
		OutputQuantity = 1,
		Ingredients = {
			{ ItemId = ItemId.Herb, Quantity = 5 },
			{ ItemId = ItemId.Crystal, Quantity = 2 },
			{ ItemId = ItemId.Stone, Quantity = 2 },
		},
		IsAutomatable = true,
		BrewStation = "BrewKettle",
	},

	[BreweryRecipeId.GreaterManaBrew] = {
		Id = BreweryRecipeId.GreaterManaBrew,
		Name = "Greater Mana Brew",
		Description = "A concentrated crystalline brew overflowing with arcane energy.",
		Icon = "rbxassetid://0",
		OutputItemId = ItemId.ManaPotion,
		OutputQuantity = 3,
		Ingredients = {
			{ ItemId = ItemId.Herb, Quantity = 5 },
			{ ItemId = ItemId.Crystal, Quantity = 3 },
		},
		IsAutomatable = true,
		BrewStation = "BrewKettle",
	},

	-- Elixirs
	[BreweryRecipeId.VitalityElixir] = {
		Id = BreweryRecipeId.VitalityElixir,
		Name = "Vitality Elixir",
		Description = "A golden brew brimming with restorative life force.",
		Icon = "rbxassetid://0",
		OutputItemId = ItemId.HealingPotion,
		OutputQuantity = 3,
		Ingredients = {
			{ ItemId = ItemId.Herb, Quantity = 6 },
			{ ItemId = ItemId.Crystal, Quantity = 2 },
			{ ItemId = ItemId.GoldOre, Quantity = 1 },
		},
		IsAutomatable = true,
		BrewStation = "BrewKettle",
	},

	[BreweryRecipeId.FortitudeElixir] = {
		Id = BreweryRecipeId.FortitudeElixir,
		Name = "Fortitude Elixir",
		Description = "A dense elixir that makes the drinker nearly impervious.",
		Icon = "rbxassetid://0",
		OutputItemId = ItemId.DefensePotion,
		OutputQuantity = 2,
		Ingredients = {
			{ ItemId = ItemId.Herb, Quantity = 5 },
			{ ItemId = ItemId.Stone, Quantity = 4 },
			{ ItemId = ItemId.Crystal, Quantity = 2 },
		},
		IsAutomatable = true,
		BrewStation = "BrewKettle",
	},

	[BreweryRecipeId.SwiftnessElixir] = {
		Id = BreweryRecipeId.SwiftnessElixir,
		Name = "Swiftness Elixir",
		Description = "A silken elixir that makes the drinker blur with speed.",
		Icon = "rbxassetid://0",
		OutputItemId = ItemId.SpeedPotion,
		OutputQuantity = 2,
		Ingredients = {
			{ ItemId = ItemId.Herb, Quantity = 5 },
			{ ItemId = ItemId.Silk, Quantity = 3 },
			{ ItemId = ItemId.Crystal, Quantity = 2 },
		},
		IsAutomatable = true,
		BrewStation = "BrewKettle",
	},

	[BreweryRecipeId.OracleElixir] = {
		Id = BreweryRecipeId.OracleElixir,
		Name = "Oracle Elixir",
		Description = "A shimmering golden brew that bends fate itself.",
		Icon = "rbxassetid://0",
		OutputItemId = ItemId.LuckPotion,
		OutputQuantity = 2,
		Ingredients = {
			{ ItemId = ItemId.Herb, Quantity = 5 },
			{ ItemId = ItemId.GoldOre, Quantity = 3 },
			{ ItemId = ItemId.Crystal, Quantity = 2 },
		},
		IsAutomatable = true,
		BrewStation = "BrewKettle",
	},

	[BreweryRecipeId.PhoenixElixir] = {
		Id = BreweryRecipeId.PhoenixElixir,
		Name = "Phoenix Elixir",
		Description = "A legendary brew said to bring the dead back from the brink.",
		Icon = "rbxassetid://0",
		OutputItemId = ItemId.GreaterHealingPotion,
		OutputQuantity = 2,
		Ingredients = {
			{ ItemId = ItemId.Herb, Quantity = 8 },
			{ ItemId = ItemId.Crystal, Quantity = 4 },
			{ ItemId = ItemId.GoldOre, Quantity = 2 },
		},
		IsAutomatable = false,
	},
}

table.freeze(BreweryRecipeConfig)
return BreweryRecipeConfig
