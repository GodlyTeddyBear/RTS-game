--!strict
local TailoringRecipeId = require(script.Parent.Parent.Types.TailoringRecipeId)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ItemId = require(ReplicatedStorage.Contexts.Inventory.Types.ItemId)

export type TTailoringIngredient = {
	ItemId: string,
	Quantity: number,
}

export type TTailoringRecipeData = {
	Id: string,
	Name: string,
	Description: string,
	Icon: string,
	OutputItemId: string,
	OutputQuantity: number,
	Ingredients: { TTailoringIngredient },
	IsAutomatable: boolean,
}

local TailoringRecipeConfig: { [string]: TTailoringRecipeData } = {

	-- Basic Cloth
	[TailoringRecipeId.LinenTunic] = {
		Id = TailoringRecipeId.LinenTunic,
		Name = "Linen Tunic",
		Description = "A simple woven tunic, the first thing any tailor learns to make.",
		Icon = "rbxassetid://0",
		OutputItemId = ItemId.LinenTunic,
		OutputQuantity = 1,
		Ingredients = {
			{ ItemId = ItemId.Herb, Quantity = 4 },
			{ ItemId = ItemId.Stone, Quantity = 2 },
		},
		IsAutomatable = true,
	},

	[TailoringRecipeId.WoolCloak] = {
		Id = TailoringRecipeId.WoolCloak,
		Name = "Wool Cloak",
		Description = "A heavy cloak spun from coarse wool, offering basic protection from the elements.",
		Icon = "rbxassetid://0",
		OutputItemId = ItemId.WoolCloak,
		OutputQuantity = 1,
		Ingredients = {
			{ ItemId = ItemId.Herb, Quantity = 5 },
			{ ItemId = ItemId.Stone, Quantity = 3 },
		},
		IsAutomatable = true,
	},

	-- Silk Tier
	[TailoringRecipeId.SilkScarf] = {
		Id = TailoringRecipeId.SilkScarf,
		Name = "Silk Scarf",
		Description = "A delicate scarf woven from pure silk, light as air.",
		Icon = "rbxassetid://0",
		OutputItemId = ItemId.SilkScarf,
		OutputQuantity = 1,
		Ingredients = {
			{ ItemId = ItemId.Silk, Quantity = 3 },
		},
		IsAutomatable = true,
	},

	[TailoringRecipeId.SilkRobe] = {
		Id = TailoringRecipeId.SilkRobe,
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
	},

	-- Accessories
	[TailoringRecipeId.SpeedBoots] = {
		Id = TailoringRecipeId.SpeedBoots,
		Name = "Speed Boots",
		Description = "Lightweight boots enchanted for swift movement.",
		Icon = "rbxassetid://0",
		OutputItemId = ItemId.SpeedBoots,
		OutputQuantity = 1,
		Ingredients = {
			{ ItemId = ItemId.Silk, Quantity = 3 },
			{ ItemId = ItemId.Herb, Quantity = 2 },
		},
		IsAutomatable = true,
	},

	[TailoringRecipeId.RogueCloak] = {
		Id = TailoringRecipeId.RogueCloak,
		Name = "Rogue Cloak",
		Description = "A lightweight cloak favoring agility over protection.",
		Icon = "rbxassetid://0",
		OutputItemId = ItemId.RogueCloak,
		OutputQuantity = 1,
		Ingredients = {
			{ ItemId = ItemId.Silk, Quantity = 4 },
			{ ItemId = ItemId.CopperOre, Quantity = 2 },
		},
		IsAutomatable = true,
	},

	-- Advanced
	[TailoringRecipeId.MageRobe] = {
		Id = TailoringRecipeId.MageRobe,
		Name = "Mage Robe",
		Description = "Enchanted robes woven with arcane thread.",
		Icon = "rbxassetid://0",
		OutputItemId = ItemId.MageRobe,
		OutputQuantity = 1,
		Ingredients = {
			{ ItemId = ItemId.Silk, Quantity = 5 },
			{ ItemId = ItemId.Crystal, Quantity = 2 },
			{ ItemId = ItemId.Herb, Quantity = 3 },
		},
		IsAutomatable = true,
	},

	[TailoringRecipeId.GoldThreadRobe] = {
		Id = TailoringRecipeId.GoldThreadRobe,
		Name = "Gold Thread Robe",
		Description = "A robe stitched with gold thread, radiating wealth and power.",
		Icon = "rbxassetid://0",
		OutputItemId = ItemId.GoldThreadRobe,
		OutputQuantity = 1,
		Ingredients = {
			{ ItemId = ItemId.Silk, Quantity = 6 },
			{ ItemId = ItemId.GoldOre, Quantity = 3 },
			{ ItemId = ItemId.Crystal, Quantity = 2 },
		},
		IsAutomatable = true,
	},

	-- Crystal Tier
	[TailoringRecipeId.CrystalVeil] = {
		Id = TailoringRecipeId.CrystalVeil,
		Name = "Crystal Veil",
		Description = "A shimmering veil threaded with focused crystal dust. Nearly impossible to replicate.",
		Icon = "rbxassetid://0",
		OutputItemId = ItemId.CrystalVeil,
		OutputQuantity = 1,
		Ingredients = {
			{ ItemId = ItemId.Silk, Quantity = 8 },
			{ ItemId = ItemId.Crystal, Quantity = 5 },
			{ ItemId = ItemId.GoldOre, Quantity = 2 },
		},
		IsAutomatable = true,
	},
}

table.freeze(TailoringRecipeConfig)
return TailoringRecipeConfig
