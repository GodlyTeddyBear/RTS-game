--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Errors = require(script.Parent.Parent.Parent.Errors)
local Result = require(ReplicatedStorage.Utilities.Result)
local Dash = require(ReplicatedStorage.Packages.Dash)
local Ok, Err, Try, Ensure, traverse = Result.Ok, Result.Err, Result.Try, Result.Ensure, Result.traverse
local MentionSuccess = Result.MentionSuccess

--[=[
	@class TailItem
	Application command for tailoring an item. Validates preconditions, consumes ingredients, and produces output.
	@server
]=]
local TailItem = {}
TailItem.__index = TailItem

--[=[ Construct a new TailItem command. @within TailItem ]=]
function TailItem.new()
	return setmetatable({}, TailItem)
end

--[=[ Initialize the command with registry access. @within TailItem @param registry any @param _name string ]=]
function TailItem:Init(registry: any, _name: string)
	self._registry = registry
	self.TailPolicy = registry:Get("TailPolicy")
end

--[=[ Resolve cross-context dependencies after all services initialize. @within TailItem ]=]
function TailItem:Start()
	self.InventoryContext = self._registry:Get("InventoryContext")
end

--[=[
	Execute the tailoring command: validate preconditions, consume ingredients, and produce output item.
	@within TailItem
	@param player Player -- The player performing the tailoring action
	@param userId number -- Player's UserId for inventory queries
	@param recipeId string -- The tailoring recipe to execute
	@return Result<string> -- Success returns the output item ID
	@error "InvalidInput" -- Player or userId is invalid
	@error "RecipeLocked" -- Recipe has not been unlocked
	@error "RecipeNotFound" -- Recipe does not exist
	@error "InsufficientMaterials" -- Missing required ingredient quantities
	@error "TailFailed" -- Ingredient consumption failed during execution
]=]
function TailItem:Execute(player: Player, userId: number, recipeId: string): Result.Result<string>
	-- Validate input parameters
	Ensure(player, "InvalidInput", "Invalid player or userId")
	Ensure(userId > 0, "InvalidInput", "Invalid player or userId")

	-- Check eligibility and fetch recipe + inventory state
	local ctx = Try(self.TailPolicy:Check(userId, recipeId))

	-- Consume all required ingredients from inventory
	Try(self:_ConsumeIngredients(userId, ctx.Recipe, ctx.InventoryState))

	-- Add the output item to the player's inventory
	Try(self.InventoryContext:AddItemToInventory(userId, ctx.Recipe.OutputItemId, ctx.Recipe.OutputQuantity))

	-- Log successful tailoring
	MentionSuccess("Tailoring:TailItem:Execute", "Tailored output item from recipe ingredients", {
		userId = userId,
		recipeId = recipeId,
		outputItemId = ctx.Recipe.OutputItemId,
		outputQuantity = ctx.Recipe.OutputQuantity,
	})

	return Ok(ctx.Recipe.OutputItemId)
end

-- Consume all ingredients from the recipe by iterating through each ingredient and deducting from slots.
function TailItem:_ConsumeIngredients(userId: number, recipe: any, inventoryState: any): Result.Result<boolean>
	return traverse(recipe.Ingredients, function(ingredient)
		return self:_ConsumeIngredient(userId, ingredient, inventoryState)
	end):andThen(function(_)
		return Ok(true)
	end)
end

-- Consume a single ingredient: find matching slots and deduct the required quantity; error if insufficient.
function TailItem:_ConsumeIngredient(userId: number, ingredient: any, inventoryState: any): Result.Result<boolean>
	local matchingSlots = self:_FindSlotsForItem(ingredient.ItemId, inventoryState)
	local quantityStillNeeded = self:_DeductFromSlots(userId, matchingSlots, ingredient.Quantity)
	if quantityStillNeeded > 0 then
		return Err("TailFailed", Errors.TAILOR_FAILED, { itemId = ingredient.ItemId })
	end
	return Ok(true)
end

-- Find and sort inventory slots containing a given item, sorted by quantity (ascending) to deplete small stacks first.
function TailItem:_FindSlotsForItem(itemId: string, inventoryState: any): { { SlotIndex: number, Quantity: number } }
	local matchingSlots = Dash.filter(inventoryState.Slots, function(slot: any)
		return slot ~= nil and slot.ItemId == itemId
	end)
	table.sort(matchingSlots, function(a: any, b: any)
		return a.Quantity < b.Quantity
	end)
	return matchingSlots
end

-- Deduct a total quantity from inventory slots in order, removing from each until the total is satisfied or slots exhausted.
function TailItem:_DeductFromSlots(userId: number, slots: { any }, totalNeeded: number): number
	local quantityStillNeeded = totalNeeded
	for _, slot in ipairs(slots) do
		if quantityStillNeeded <= 0 then break end
		-- Deduct the minimum of what we need and what the slot has
		local quantityToDeduct = math.min(quantityStillNeeded, slot.Quantity)
		Try(self.InventoryContext:RemoveItemFromInventory(userId, slot.SlotIndex, quantityToDeduct))
		quantityStillNeeded = quantityStillNeeded - quantityToDeduct
	end
	return quantityStillNeeded
end

return TailItem
