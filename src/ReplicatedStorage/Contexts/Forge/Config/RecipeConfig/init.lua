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
	--- Player needs any one of these BuildingType keys placed (timed smelts use the machine UI).
	RequiredMachines: { string }?,
	--- When set > 0, recipe runs on the timed machine pipeline (not instant CraftItem).
	ProcessDurationSeconds: number?,
	--- Preferred forge station used for worker placement and building access checks.
	ForgeStation: "Anvil" | "WorkBench",
}

local Materials = require(script.Materials)
local Weapons = require(script.Weapons)
local Armor = require(script.Armor)
local Accessories = require(script.Accessories)
local Consumables = require(script.Consumables)

local RecipeConfig: { [string]: TRecipeData } = {}

for id, recipe in Materials do
	RecipeConfig[id] = recipe
end
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
