--!strict

export type TIngredient = {
	ItemId: string,
	Quantity: number,
}

export type TRecipeData = {
	Id: string,
	Name: string,
	Description: string,
	Icon: string,
	OutputItemId: string,
	OutputQuantity: number,
	Ingredients: { TIngredient },
	IsAutomatable: boolean,
	QualityUpgrades: { [string]: string }?,
	--- Future scope: player needs one of these structure ids placed.
	RequiredStructures: { string }?,
	--- Future scope: when set > 0, recipe runs on a timed structure pipeline instead of instant CraftItem.
	ProcessDurationSeconds: number?,
}

local Materials = require(script.Materials)
local Weapons = require(script.Weapons)
local Armor = require(script.Armor)
local Accessories = require(script.Accessories)
local Consumables = require(script.Consumables)

local RecipeConfig: { [string]: TRecipeData } = table.clone(Materials)

for id, recipe in Weapons do
	RecipeConfig[id] = recipe
end
for id, recipe in Armor do
	RecipeConfig[id] = recipe
end
for id, recipe in Accessories do
	RecipeConfig[id] = recipe
end
for id, recipe in Consumables do
	RecipeConfig[id] = recipe
end

table.freeze(RecipeConfig)
return RecipeConfig
