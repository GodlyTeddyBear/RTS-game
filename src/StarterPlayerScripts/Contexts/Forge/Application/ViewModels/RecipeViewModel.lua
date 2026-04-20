--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RecipeConfig = require(ReplicatedStorage.Contexts.Forge.Config.RecipeConfig)
local ItemConfig = require(ReplicatedStorage.Contexts.Inventory.Config.ItemConfig)
local UnlockConfig = require(ReplicatedStorage.Contexts.Unlock.Config.UnlockConfig)
local UnlockTypes = require(ReplicatedStorage.Contexts.Unlock.Types.UnlockTypes)

--[=[
	@interface TIngredientDisplay
	Display data for a single ingredient requirement.
	.ItemId string -- Config key for the item
	.Name string -- Human-readable item name
	.Required number -- Quantity needed for recipe
	.Have number -- Quantity player currently owns
	.Met boolean -- Whether requirement is satisfied
]=]
export type TIngredientDisplay = {
	ItemId: string,
	Name: string,
	Required: number,
	Have: number,
	Met: boolean,
}

--[=[
	@interface TRecipeViewModel
	View model for a single recipe; ready for UI rendering.
	.Id string -- Recipe config key
	.Name string -- Display name
	.Description string -- Flavor text
	.Icon string -- Asset ID for recipe icon
	.OutputItemId string -- Config key for crafted item
	.OutputName string -- Human-readable output item name
	.OutputQuantity number -- Quantity produced per craft
	.Ingredients { TIngredientDisplay } -- List of required ingredients
	.CanAfford boolean -- Whether player has all required items
]=]
export type TRecipeViewModel = {
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
	@class RecipeViewModel
	Factory for transforming recipe and inventory data into display-ready view models.
	@client
]=]
local RecipeViewModel = {}

local function _isRecipeUnlocked(recipeId: string, unlockState: UnlockTypes.TUnlockState?): boolean
	local entry = UnlockConfig[recipeId]
	if not entry or entry.StartsUnlocked then
		return true
	end

	local resolvedUnlockState = unlockState or {}
	return resolvedUnlockState[recipeId] == true
end

-- Aggregate inventory state into a map of ItemId → total quantity across all slots
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
	Transform raw recipe config and current inventory state into a display-ready view model.
	@within RecipeViewModel
	@param recipe any -- Recipe data from RecipeConfig (id, name, description, ingredients, output, quantity)
	@param inventoryState any -- Current inventory atom state (slots)
	@return TRecipeViewModel -- Frozen view model ready for rendering
]=]
function RecipeViewModel.fromRecipe(recipe: any, inventoryState: any): TRecipeViewModel
	-- Map available inventory by item ID
	local available = _BuildAvailableMap(inventoryState)

	local ingredients: { TIngredientDisplay } = {}
	local canAfford = true

	-- Build ingredient list and check affordability
	for _, ingredient in ipairs(recipe.Ingredients) do
		-- Check if we have enough of this ingredient
		local have = available[ingredient.ItemId] or 0
		local met = have >= ingredient.Quantity
		if not met then
			canAfford = false
		end

		-- Resolve item display name from config
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

	-- Resolve output item display name from config
	local outputData = ItemConfig[recipe.OutputItemId]
	local outputName = if outputData then outputData.name else recipe.OutputItemId

	-- Assemble and freeze the view model
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
	}) :: TRecipeViewModel
end

--[=[
	Build view models for all instant (non-timed) recipes given current inventory state.
	@within RecipeViewModel
	@param inventoryState any -- Current inventory atom state
	@return { TRecipeViewModel } -- List of view models, sorted alphabetically by name
]=]
function RecipeViewModel.allFromInventory(
	inventoryState: any,
	unlockState: UnlockTypes.TUnlockState?
): { TRecipeViewModel }
	local viewModels: { TRecipeViewModel } = {}

	-- Filter for instant recipes only (skip timed/brewing recipes)
	for recipeId, recipe in pairs(RecipeConfig) do
		local isTimed = recipe.ProcessDurationSeconds and recipe.ProcessDurationSeconds > 0
		local isUnlocked = _isRecipeUnlocked(recipeId, unlockState)
		if not isTimed and isUnlocked then
			table.insert(viewModels, RecipeViewModel.fromRecipe(recipe, inventoryState))
		end
	end

	-- Sort alphabetically by name for consistent ordering
	table.sort(viewModels, function(a, b)
		return a.Name < b.Name
	end)
	return viewModels
end

return RecipeViewModel
