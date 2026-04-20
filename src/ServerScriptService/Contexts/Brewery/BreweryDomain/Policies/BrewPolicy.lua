--!strict

--[[
	BrewPolicy — Domain Policy

	Answers: can this player brew the given recipe?

	RESPONSIBILITIES:
	  1. Fetch inventory state from InventoryContext
	  2. Look up the recipe from BreweryRecipeConfig
	  3. Sum available ingredient quantities from inventory slots
	  4. Build a TBrewItemCandidate and evaluate CanBrewItem
	  5. Return Ok({ Recipe, InventoryState }) so the command avoids re-reads

	RESULT:
	  Ok({ Recipe, InventoryState }) — brew is valid; recipe and inventory returned for command use
	  Err(...)                       — recipe not found or insufficient materials

	USAGE:
	  -- Inside a Catch boundary (Application command):
	  local ctx = Try(self.BrewPolicy:Check(userId, recipeId))
	  local recipe        = ctx.Recipe
	  local inventoryState = ctx.InventoryState
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local BreweryRecipeConfig = require(ReplicatedStorage.Contexts.Brewery.Config.BreweryRecipeConfig)
local BrewerySpecs = require(script.Parent.Parent.Specs.BrewerySpecs)
local Result = require(ReplicatedStorage.Utilities.Result)

local Ok = Result.Ok
local Try = Result.Try

--[=[
	@class BrewPolicy
	Domain policy validating recipe brew eligibility and gathering required context.
	@server
]=]

local BrewPolicy = {}
BrewPolicy.__index = BrewPolicy

export type TBrewPolicy = typeof(setmetatable({}, BrewPolicy))

--[=[
	Construct a new BrewPolicy instance.
	@within BrewPolicy
	@return TBrewPolicy
]=]
function BrewPolicy.new(): TBrewPolicy
	return setmetatable({}, BrewPolicy)
end

--[=[
	Initialize the policy with a service registry.
	@within BrewPolicy
	@param registry any -- Service registry for dependency resolution
]=]
function BrewPolicy:Init(registry: any)
	self._registry = registry
end

--[=[
	Start the policy; resolve cross-context dependencies.
	@within BrewPolicy
]=]
function BrewPolicy:Start()
	self.InventoryContext = self._registry:Get("InventoryContext")
	self.UnlockContext = self._registry:Get("UnlockContext")
end

--[=[
	Validate that a player can brew a recipe and return recipe + inventory context.
	Ensures recipe exists, is unlocked, and player has sufficient materials.
	@within BrewPolicy
	@param userId number -- Player's user ID
	@param recipeId string -- Recipe to validate
	@return Result -- Ok with table { Recipe, InventoryState }, or Err with validation failure
]=]
function BrewPolicy:Check(userId: number, recipeId: string): Result.Result<{ Recipe: any, InventoryState: any }>
	-- Step 1: Fetch authoritative player inventory state
	local inventoryState = Try(self.InventoryContext:GetPlayerInventory(userId))

	-- Step 2: Look up recipe from configuration
	local recipe = BreweryRecipeConfig[recipeId]

	-- Step 3: Calculate total available quantity per ingredient item ID
	local available: { [string]: number } = {}
	if inventoryState and inventoryState.Slots then
		for _, slot in pairs(inventoryState.Slots) do
			if slot and slot.ItemId then
				available[slot.ItemId] = (available[slot.ItemId] or 0) + slot.Quantity
			end
		end
	end

	-- Step 4: Verify player has sufficient of each ingredient
	local sufficientMaterials = true
	if recipe then
		for _, ingredient in ipairs(recipe.Ingredients) do
			if (available[ingredient.ItemId] or 0) < ingredient.Quantity then
				sufficientMaterials = false
				break
			end
		end
	end

	-- Step 5: Build candidate and evaluate all brew eligibility specs
	local candidate: BrewerySpecs.TBrewItemCandidate = {
		RecipeExists        = recipe ~= nil,
		-- Defensive: passes when recipe unknown — only the root error fires
		SufficientMaterials = recipe == nil or sufficientMaterials,
		IsUnlocked          = self.UnlockContext:IsUnlocked(userId, recipeId),
	}

	Try(BrewerySpecs.CanBrewItem:IsSatisfiedBy(candidate))

	-- Step 6: Return validated recipe and inventory for command execution
	return Ok({ Recipe = recipe, InventoryState = inventoryState })
end

return BrewPolicy
