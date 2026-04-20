--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Errors = require(script.Parent.Parent.Parent.Errors)
local Result = require(ReplicatedStorage.Utilities.Result)
local Ok, Err, Try, Ensure = Result.Ok, Result.Err, Result.Try, Result.Ensure
local MentionSuccess = Result.MentionSuccess

--[=[
	@class BrewItem
	Application command: brew a recipe and grant the output item to inventory.
	@server
]=]

local BrewItem = {}
BrewItem.__index = BrewItem

--[=[
	Construct a new BrewItem command instance.
	@within BrewItem
	@return BrewItem
]=]
function BrewItem.new()
	return setmetatable({}, BrewItem)
end

--[=[
	Initialize the command with a service registry and resolve dependencies.
	@within BrewItem
	@param registry any -- Service registry
	@param _name string -- Service name (unused)
]=]
function BrewItem:Init(registry: any, _name: string)
	self._registry = registry
	self.BrewPolicy = registry:Get("BrewPolicy")
end

--[=[
	Start the command; resolve cross-context dependencies.
	@within BrewItem
]=]
function BrewItem:Start()
	self.InventoryContext = self._registry:Get("InventoryContext")
end

--[=[
	Execute a brew operation: validate recipe, consume ingredients, grant output.
	@within BrewItem
	@param player Player -- Player brewing the recipe
	@param userId number -- Player's user ID
	@param recipeId string -- Recipe to brew
	@return Result -- Ok with output item ID, or Err if validation/execution fails
]=]
function BrewItem:Execute(player: Player, userId: number, recipeId: string): Result.Result<string>
	Ensure(player ~= nil and userId > 0, "InvalidInput", "Invalid player or userId")

	-- Step 1: Validate recipe and fetch inventory state
	local ctx = Try(self.BrewPolicy:Check(userId, recipeId))
	local recipe         = ctx.Recipe
	local inventoryState = ctx.InventoryState

	-- Step 2: Remove all ingredient quantities from inventory
	for _, ingredient in ipairs(recipe.Ingredients) do
		local remaining = ingredient.Quantity

		-- Collect all slots containing this ingredient
		local matchingSlots: { { SlotIndex: number, Quantity: number } } = {}
		for slotIndex, slot in pairs(inventoryState.Slots) do
			if slot and slot.ItemId == ingredient.ItemId then
				table.insert(matchingSlots, { SlotIndex = slotIndex, Quantity = slot.Quantity })
			end
		end

		-- Sort by quantity ascending so we deplete smallest stacks first
		table.sort(matchingSlots, function(a, b)
			return a.Quantity < b.Quantity
		end)

		-- Remove required quantity from each matching slot until ingredient satisfied
		for _, slotInfo in ipairs(matchingSlots) do
			if remaining <= 0 then
				break
			end
			local toRemove = math.min(remaining, slotInfo.Quantity)
			Try(self.InventoryContext:RemoveItemFromInventory(userId, slotInfo.SlotIndex, toRemove))
			remaining = remaining - toRemove
		end

		-- Safety check: if we couldn't find enough, fail (should not happen after BrewPolicy validation)
		if remaining > 0 then
			return Err("BrewFailed", Errors.BREW_FAILED, { itemId = ingredient.ItemId })
		end
	end

	-- Step 3: Grant the brewed output item to inventory
	Try(self.InventoryContext:AddItemToInventory(userId, recipe.OutputItemId, recipe.OutputQuantity))

	-- Step 4: Log and return success
	MentionSuccess("Brewery:BrewItem:Execute", "Brewed output item from recipe ingredients", {
		userId = userId,
		recipeId = recipeId,
		outputItemId = recipe.OutputItemId,
		outputQuantity = recipe.OutputQuantity,
	})

	return Ok(recipe.OutputItemId)
end

return BrewItem
