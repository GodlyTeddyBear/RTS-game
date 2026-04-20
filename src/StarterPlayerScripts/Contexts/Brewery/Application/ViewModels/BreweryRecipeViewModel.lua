--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local BreweryRecipeConfig = require(ReplicatedStorage.Contexts.Brewery.Config.BreweryRecipeConfig)
local ItemConfig = require(ReplicatedStorage.Contexts.Inventory.Config.ItemConfig)

--[=[
	@interface TIngredientDisplay
	@within BreweryRecipeViewModel
	Display-ready ingredient with availability tracking.
	.ItemId string -- Unique identifier for the ingredient item
	.Name string -- Display name of the ingredient
	.Required number -- Quantity needed for the recipe
	.Have number -- Current quantity in inventory
	.Met boolean -- Whether the requirement is satisfied
]=]
export type TIngredientDisplay = {
	ItemId: string,
	Name: string,
	Required: number,
	Have: number,
	Met: boolean,
}

--[=[
	@interface TBreweryRecipeViewModel
	@within BreweryRecipeViewModel
	Display-ready recipe with ingredient availability and affordability status.
	.Id string -- Unique identifier for the recipe
	.Name string -- Display name of the recipe
	.Description string -- Human-readable description
	.Icon string -- Asset ID for the recipe icon
	.OutputItemId string -- The item produced by this recipe
	.OutputName string -- Display name of the output item
	.OutputQuantity number -- Quantity produced per brew
	.Ingredients {TIngredientDisplay} -- List of required ingredients with availability
	.CanAfford boolean -- Whether all ingredients are available
]=]
export type TBreweryRecipeViewModel = {
	Id: string,
	Name: string,
	Description: string,
	Icon: string,
	OutputItemId: string,
	OutputName: string,
	OutputQuantity: number,
	Ingredients: { TIngredientDisplay },
	CanAfford: boolean,
}

--[=[
	@class BreweryRecipeViewModel
	Transforms raw recipe and inventory data into display-ready view models for UI consumption.
	@client
]=]
local BreweryRecipeViewModel = {}

-- Aggregate all items by ID and sum their quantities from inventory slots; guard against nil slots.
local function _BuildAvailableMap(inventoryState: any): { [string]: number }
	local available: { [string]: number } = {}
	if inventoryState and inventoryState.Slots then
		for _, slot in pairs(inventoryState.Slots) do
			if slot and slot.ItemId then
				available[slot.ItemId] = (available[slot.ItemId] or 0) + slot.Quantity
			end
		end
	end
	return available
end

--[=[
	Transform raw recipe data and current inventory into a display-ready view model.
	@within BreweryRecipeViewModel
	@param recipe any -- TBreweryRecipeData from BreweryRecipeConfig
	@param inventoryState any -- TInventoryState from the inventory atom
	@return TBreweryRecipeViewModel -- Frozen view model ready for rendering
]=]
function BreweryRecipeViewModel.fromRecipe(recipe: any, inventoryState: any): TBreweryRecipeViewModel
	local available = _BuildAvailableMap(inventoryState)

	local ingredients: { TIngredientDisplay } = {}
	local canAfford = true

	-- Build ingredient display list and check affordability
	for _, ingredient in ipairs(recipe.Ingredients) do
		local have = available[ingredient.ItemId] or 0
		local met = have >= ingredient.Quantity
		if not met then
			canAfford = false
		end

		-- Resolve display name from item config, fall back to ItemId
		local itemData = ItemConfig[ingredient.ItemId]
		local itemName = if itemData then itemData.name else ingredient.ItemId

		table.insert(ingredients, {
			ItemId = ingredient.ItemId,
			Name = itemName,
			Required = ingredient.Quantity,
			Have = have,
			Met = met,
		})
	end

	-- Resolve output item name from config, fall back to ItemId
	local outputData = ItemConfig[recipe.OutputItemId]
	local outputName = if outputData then outputData.name else recipe.OutputItemId

	return table.freeze({
		Id = recipe.Id,
		Name = recipe.Name,
		Description = recipe.Description,
		Icon = recipe.Icon,
		OutputItemId = recipe.OutputItemId,
		OutputName = outputName,
		OutputQuantity = recipe.OutputQuantity,
		Ingredients = ingredients,
		CanAfford = canAfford,
	}) :: TBreweryRecipeViewModel
end

--[=[
	Build view models for all brewery recipes given the current inventory state.
	@within BreweryRecipeViewModel
	@param inventoryState any -- TInventoryState
	@return {TBreweryRecipeViewModel} -- List of view models sorted alphabetically by name
]=]
function BreweryRecipeViewModel.allFromInventory(inventoryState: any): { TBreweryRecipeViewModel }
	local viewModels: { TBreweryRecipeViewModel } = {}
	for _, recipe in pairs(BreweryRecipeConfig) do
		table.insert(viewModels, BreweryRecipeViewModel.fromRecipe(recipe, inventoryState))
	end
	-- Sort alphabetically by name for consistent ordering
	table.sort(viewModels, function(a, b)
		return a.Name < b.Name
	end)
	return viewModels
end

return BreweryRecipeViewModel
