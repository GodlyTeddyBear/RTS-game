--!strict

--[[
	CraftPolicy — Domain Policy

	Answers: can this player craft the given recipe?

	RESPONSIBILITIES:
	  1. Fetch inventory state from InventoryContext
	  2. Look up the recipe from RecipeConfig
	  3. Sum available ingredient quantities from inventory slots
	  4. Build a TCraftItemCandidate and evaluate CanCraftItem
	  5. Return Ok({ Recipe, InventoryState }) so the command avoids re-reads

	RESULT:
	  Ok({ Recipe, InventoryState }) — craft is valid; recipe and inventory returned for command use
	  Err(...)                       — recipe not found or insufficient materials

	USAGE:
	  -- Inside a Catch boundary (Application command):
	  local ctx = Try(self.CraftPolicy:Check(userId, recipeId))
	  local recipe        = ctx.Recipe
	  local inventoryState = ctx.InventoryState
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RecipeConfig = require(ReplicatedStorage.Contexts.Forge.Config.RecipeConfig)
local ForgeStationConfig = require(ReplicatedStorage.Contexts.Forge.Config.ForgeStationConfig)
local ForgeSpecs = require(script.Parent.Parent.Specs.ForgeSpecs)
local Result = require(ReplicatedStorage.Utilities.Result)

local Ok = Result.Ok
local Try = Result.Try

--[=[
	@class CraftPolicy
	Domain policy: validate craft eligibility by checking recipe existence, material availability, and recipe type.
	@server
]=]
local CraftPolicy = {}
CraftPolicy.__index = CraftPolicy

export type TCraftPolicy = typeof(setmetatable({}, CraftPolicy))

--[=[
	@function CraftPolicy.new
	@within CraftPolicy
	Create a new CraftPolicy instance. Dependencies are resolved during Init/Start phases.
	@return CraftPolicy
]=]
function CraftPolicy.new(): TCraftPolicy
	return setmetatable({}, CraftPolicy)
end

--[=[
	@method Init
	@within CraftPolicy
	Initialize the policy: cache the registry for dependency resolution.
	@param registry any -- Service registry
]=]
function CraftPolicy:Init(registry: any)
	self._registry = registry
end

--[=[
	@method Start
	@within CraftPolicy
	Start the policy: resolve InventoryContext cross-context dependency.
]=]
function CraftPolicy:Start()
	self.InventoryContext = self._registry:Get("InventoryContext")
	self.UnlockContext = self._registry:Get("UnlockContext")
	self.BuildingContext = self._registry:Get("BuildingContext")
end

--[=[
	@method Check
	@within CraftPolicy
	Validate craft eligibility: check recipe existence, material availability, and recipe type.
	@param userId number -- The player's user ID
	@param recipeId string -- The recipe to validate
	@return Result<{ Recipe: any, InventoryState: any }> -- Ok with recipe and inventory state, or Err with failure reason
]=]
function CraftPolicy:Check(userId: number, recipeId: string): Result.Result<{ Recipe: any, InventoryState: any }>
	-- Step 1: Fetch player's inventory state
	local inventoryState = Try(self.InventoryContext:GetPlayerInventory(userId))

	-- Step 2: Look up recipe from configuration
	local recipe = RecipeConfig[recipeId]
	local stationInfo = recipe and ForgeStationConfig[recipe.ForgeStation] or nil
	local requiredBuildingType = stationInfo and stationInfo.BuildingType or nil

	-- Step 3: Sum available quantities per ingredient item ID
	local available: { [string]: number } = {}
	if inventoryState and inventoryState.Slots then
		for _, slot in pairs(inventoryState.Slots) do
			if slot and slot.ItemId then
				available[slot.ItemId] = (available[slot.ItemId] or 0) + slot.Quantity
			end
		end
	end

	-- Step 4: Check if player has all required ingredients
	local sufficientMaterials = true
	if recipe then
		for _, ingredient in ipairs(recipe.Ingredients) do
			if (available[ingredient.ItemId] or 0) < ingredient.Quantity then
				sufficientMaterials = false
				break
			end
		end
	end

	-- Step 5: Check if recipe is instant-craft (ProcessDurationSeconds missing or <= 0)
	local isInstantCraft = recipe == nil
		or recipe.ProcessDurationSeconds == nil
		or recipe.ProcessDurationSeconds <= 0

	-- Step 6: Build candidate and evaluate specs
	local candidate: ForgeSpecs.TCraftItemCandidate = {
		RecipeExists        = recipe ~= nil,
		IsRecipeUnlocked = recipe == nil or self.UnlockContext:IsUnlocked(userId, recipeId),
		HasRequiredForgeBuilding = recipe == nil
			or (requiredBuildingType ~= nil and self.BuildingContext:HasBuildingForUser(userId, "Forge", requiredBuildingType)),
		-- Defensive: passes when recipe unknown — only the root error (RecipeNotFound) fires
		SufficientMaterials = recipe == nil or sufficientMaterials,
		-- Defensive: passes when recipe unknown — only the root error fires
		IsInstantCraftRecipe = recipe == nil or isInstantCraft,
	}

	Try(ForgeSpecs.CanCraftItem:IsSatisfiedBy(candidate))

	-- Step 7: Return recipe and inventory state for command to use (avoids re-fetch)
	return Ok({ Recipe = recipe, InventoryState = inventoryState })
end

return CraftPolicy
