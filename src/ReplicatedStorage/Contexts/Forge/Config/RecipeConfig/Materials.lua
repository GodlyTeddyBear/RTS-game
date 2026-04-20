--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RecipeId = require(script.Parent.Parent.Parent.Types.RecipeId)
local ItemId = require(ReplicatedStorage.Contexts.Inventory.Types.ItemId)

local Materials: { [string]: any } = {
	-- Chapter 1 — produced at the Forest zone lumberjack machine
	[RecipeId.Charcoal] = {
		Id = RecipeId.Charcoal,
		Name = "Charcoal",
		Description = "Charred wood used as fuel. Required by the smelter on every smelt.",
		Icon = "rbxassetid://0",
		OutputItemId = ItemId.Charcoal,
		OutputQuantity = 1,
		Ingredients = {
			{ ItemId = ItemId.Wood, Quantity = 1 },
		},
		IsAutomatable = true,
		RequiredMachines = { "LumberjackMachine" },
		ProcessDurationSeconds = 6,
		ForgeStation = "WorkBench",
	},

	[RecipeId.CopperPlate] = {
		Id = RecipeId.CopperPlate,
		Name = "Copper Plate",
		Description = "A refined copper plate smelted from raw ore.",
		Icon = "rbxassetid://0",
		OutputItemId = ItemId.CopperPlate,
		OutputQuantity = 1,
		Ingredients = {
			{ ItemId = ItemId.CopperOre, Quantity = 3 },
		},
		IsAutomatable = false,
		RequiredMachines = { "Smelter" },
		ProcessDurationSeconds = 4,
		ForgeStation = "Anvil",
	},

	[RecipeId.IronPlate] = {
		Id = RecipeId.IronPlate,
		Name = "Iron Plate",
		Description = "A refined iron plate smelted from raw ore at the forge hearth.",
		Icon = "rbxassetid://0",
		OutputItemId = ItemId.IronPlate,
		OutputQuantity = 1,
		Ingredients = {
			{ ItemId = ItemId.IronOre, Quantity = 3 },
		},
		IsAutomatable = false,
		RequiredMachines = { "Smelter" },
		ProcessDurationSeconds = 6,
		ForgeStation = "Anvil",
	},

	[RecipeId.SteelPlate] = {
		Id = RecipeId.SteelPlate,
		Name = "Steel Plate",
		Description = "Tempered steel plate, superior to iron in every way.",
		Icon = "rbxassetid://0",
		OutputItemId = ItemId.SteelPlate,
		OutputQuantity = 1,
		Ingredients = {
			{ ItemId = ItemId.IronPlate, Quantity = 2 },
			{ ItemId = ItemId.Coal, Quantity = 2 },
		},
		IsAutomatable = true,
		ForgeStation = "Anvil",
	},

	[RecipeId.GoldPlate] = {
		Id = RecipeId.GoldPlate,
		Name = "Gold Plate",
		Description = "A gleaming plate of refined gold.",
		Icon = "rbxassetid://0",
		OutputItemId = ItemId.GoldPlate,
		OutputQuantity = 1,
		Ingredients = {
			{ ItemId = ItemId.GoldOre, Quantity = 4 },
			{ ItemId = ItemId.Coal, Quantity = 2 },
		},
		IsAutomatable = true,
		ForgeStation = "Anvil",
	},
}

return Materials
