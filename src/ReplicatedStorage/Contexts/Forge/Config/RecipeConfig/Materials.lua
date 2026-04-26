--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RecipeId = require(script.Parent.Parent.Parent.Types.RecipeId)
local ItemId = require(ReplicatedStorage.Contexts.Inventory.Types.ItemId)

local Materials: { [string]: any } = {
	[RecipeId.Alloy] = {
		Id = RecipeId.Alloy,
		Name = "Alloy",
		Description = "Refined battlefield metal used for durable structure components.",
		Icon = "rbxassetid://0",
		OutputItemId = ItemId.Alloy,
		OutputQuantity = 1,
		Ingredients = {
			{ ItemId = ItemId.Scrap, Quantity = 4 },
		},
		IsAutomatable = true,
		RequiredStructures = { "FutureForge" },
	},

	[RecipeId.Circuit] = {
		Id = RecipeId.Circuit,
		Name = "Circuit",
		Description = "Rebuilt control circuitry assembled from salvage and reinforced metal.",
		Icon = "rbxassetid://0",
		OutputItemId = ItemId.Circuit,
		OutputQuantity = 1,
		Ingredients = {
			{ ItemId = ItemId.Scrap, Quantity = 2 },
			{ ItemId = ItemId.Alloy, Quantity = 1 },
		},
		IsAutomatable = true,
		RequiredStructures = { "FutureAssembler" },
	},

	[RecipeId.PowerCore] = {
		Id = RecipeId.PowerCore,
		Name = "Power Core",
		Description = "A compact energy core assembled from advanced components and relic fragments.",
		Icon = "rbxassetid://0",
		OutputItemId = ItemId.PowerCore,
		OutputQuantity = 1,
		Ingredients = {
			{ ItemId = ItemId.Alloy, Quantity = 2 },
			{ ItemId = ItemId.Circuit, Quantity = 2 },
			{ ItemId = ItemId.RelicShard, Quantity = 1 },
		},
		IsAutomatable = false,
		RequiredStructures = { "FutureReactor" },
	},
}

return table.freeze(Materials)
