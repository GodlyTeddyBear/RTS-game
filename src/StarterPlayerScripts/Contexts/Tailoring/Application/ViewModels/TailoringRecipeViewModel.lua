--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TailoringRecipeConfig = require(ReplicatedStorage.Contexts.Tailoring.Config.TailoringRecipeConfig)
local ItemConfig = require(ReplicatedStorage.Contexts.Inventory.Config.ItemConfig)

export type TIngredientDisplay = {
	ItemId: string,
	Name: string,
	Required: number,
	Have: number,
	Met: boolean,
}

export type TTailoringRecipeViewModel = {
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

local TailoringRecipeViewModel = {}

--- Build a map of ItemId → total quantity from inventory state
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

--- Transforms raw tailoring recipe data + inventory state into a display-ready view model.
-- @param recipe TTailoringRecipeData from TailoringRecipeConfig
-- @param inventoryState TInventoryState from the inventory atom
-- @return TTailoringRecipeViewModel (frozen)
function TailoringRecipeViewModel.fromRecipe(recipe: any, inventoryState: any): TTailoringRecipeViewModel
	local available = _BuildAvailableMap(inventoryState)

	local ingredients: { TIngredientDisplay } = {}
	local canAfford = true

	for _, ingredient in ipairs(recipe.Ingredients) do
		local have = available[ingredient.ItemId] or 0
		local met = have >= ingredient.Quantity
		if not met then
			canAfford = false
		end

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
	}) :: TTailoringRecipeViewModel
end

--- Build view models for all tailoring recipes given current inventory state.
-- @param inventoryState TInventoryState
-- @return { TTailoringRecipeViewModel }
function TailoringRecipeViewModel.allFromInventory(inventoryState: any): { TTailoringRecipeViewModel }
	local viewModels: { TTailoringRecipeViewModel } = {}
	for _, recipe in pairs(TailoringRecipeConfig) do
		table.insert(viewModels, TailoringRecipeViewModel.fromRecipe(recipe, inventoryState))
	end
	-- Sort alphabetically by name for consistent ordering
	table.sort(viewModels, function(a, b)
		return a.Name < b.Name
	end)
	return viewModels
end

return TailoringRecipeViewModel
