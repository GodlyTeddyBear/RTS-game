--!strict

--[[
	TailPolicy — Domain Policy

	Answers: can this player tailor the given recipe?

	RESPONSIBILITIES:
	  1. Fetch inventory state from InventoryContext
	  2. Look up the recipe from TailoringRecipeConfig
	  3. Sum available ingredient quantities from inventory slots
	  4. Build a TTailItemCandidate and evaluate CanTailItem
	  5. Return Ok({ Recipe, InventoryState }) so the command avoids re-reads

	RESULT:
	  Ok({ Recipe, InventoryState }) — tailoring is valid; recipe and inventory returned for command use
	  Err(...)                       — recipe not found or insufficient materials

	USAGE:
	  -- Inside a Catch boundary (Application command):
	  local ctx = Try(self.TailPolicy:Check(userId, recipeId))
	  local recipe         = ctx.Recipe
	  local inventoryState = ctx.InventoryState
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TailoringRecipeConfig = require(ReplicatedStorage.Contexts.Tailoring.Config.TailoringRecipeConfig)
local TailoringSpecs = require(script.Parent.Parent.Specs.TailoringSpecs)
local Result = require(ReplicatedStorage.Utilities.Result)
local Dash = require(ReplicatedStorage.Packages.Dash)

local Ok = Result.Ok
local Try = Result.Try

--[=[
	@class TailPolicy
	Domain policy: evaluates tailoring eligibility and returns recipe + inventory context for safe execution.
	@server
]=]
local TailPolicy = {}
TailPolicy.__index = TailPolicy

export type TTailPolicy = typeof(setmetatable({}, TailPolicy))

--[=[ Construct a new TailPolicy. @within TailPolicy ]=]
function TailPolicy.new(): TTailPolicy
	return setmetatable({}, TailPolicy)
end

--[=[ Initialize the policy with registry access. @within TailPolicy @param registry any ]=]
function TailPolicy:Init(registry: any)
	self._registry = registry
end

--[=[ Resolve cross-context dependencies after all services initialize. @within TailPolicy ]=]
function TailPolicy:Start()
	self.InventoryContext = self._registry:Get("InventoryContext")
	self.UnlockContext = self._registry:Get("UnlockContext")
end

--[=[
	Check if a player can tailor a recipe. Fetches inventory, looks up recipe, builds a candidate, and evaluates eligibility.
	@within TailPolicy
	@param userId number -- Player's UserId
	@param recipeId string -- The tailoring recipe to check
	@return Result<{ Recipe: any, InventoryState: any }> -- Success returns recipe and inventory state for command use
	@error "RecipeLocked" -- Recipe has not been unlocked
	@error "RecipeNotFound" -- Recipe does not exist
	@error "InsufficientMaterials" -- Missing required ingredient quantities
]=]
function TailPolicy:Check(userId: number, recipeId: string): Result.Result<{ Recipe: any, InventoryState: any }>
	return self.InventoryContext:GetPlayerInventory(userId):andThen(function(inventoryState)
		local recipe = TailoringRecipeConfig[recipeId]
		local available = self:_SumAvailableQuantities(inventoryState)
		local candidate = self:_BuildCandidate(recipe, available, userId, recipeId)
		Try(TailoringSpecs.CanTailItem:IsSatisfiedBy(candidate))
		return Ok({ Recipe = recipe, InventoryState = inventoryState })
	end)
end

-- Sum available quantities per item ID from inventory slots; returns empty table if inventory is invalid.
function TailPolicy:_SumAvailableQuantities(inventoryState: any): { [string]: number }
	if not (inventoryState and inventoryState.Slots) then return {} end
	return Dash.reduce(inventoryState.Slots, function(acc: { [string]: number }, slot: any)
		if slot and slot.ItemId then
			acc[slot.ItemId] = (acc[slot.ItemId] or 0) + slot.Quantity
		end
		return acc
	end, {})
end

-- Build a tailoring candidate for spec evaluation; defensively set SufficientMaterials=true when recipe is missing to avoid false positives on the second spec error.
function TailPolicy:_BuildCandidate(recipe: any, available: { [string]: number }, userId: number, recipeId: string): TailoringSpecs.TTailItemCandidate
	return {
		RecipeExists = recipe ~= nil,
		-- Defensive: passes when recipe unknown — only the root error fires
		SufficientMaterials = recipe == nil or self:_HasAllIngredients(recipe, available),
		IsUnlocked = self.UnlockContext:IsUnlocked(userId, recipeId),
	}
end

-- Check if the player has all required ingredient quantities in available inventory.
function TailPolicy:_HasAllIngredients(recipe: any, available: { [string]: number }): boolean
	for _, ingredient in ipairs(recipe.Ingredients) do
		if (available[ingredient.ItemId] or 0) < ingredient.Quantity then
			return false
		end
	end
	return true
end

return TailPolicy
