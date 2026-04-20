--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local BreweryRecipeConfig = require(ReplicatedStorage.Contexts.Brewery.Config.BreweryRecipeConfig)
local WorkerSpecs = require(script.Parent.Parent.Specs.WorkerSpecs)
local WorkerInventoryUtils = require(script.Parent.Parent.Services.WorkerInventoryUtils)
local Result = require(ReplicatedStorage.Utilities.Result)

local Ok = Result.Ok
local Try = Result.Try

local BreweryTickPolicy = {}
BreweryTickPolicy.__index = BreweryTickPolicy

function BreweryTickPolicy.new()
	return setmetatable({}, BreweryTickPolicy)
end

function BreweryTickPolicy:Init(registry: any, _name: string)
	self._registry = registry
end

function BreweryTickPolicy:Start()
	self._inventoryContext = self._registry:Get("InventoryContext")
	self._unlockContext = self._registry:Get("UnlockContext")
	self._buildingContext = self._registry:Get("BuildingContext")
end

function BreweryTickPolicy:Check(assignment: any, userId: number)
	local hasRecipe = assignment.TaskTarget ~= nil
	local recipe = hasRecipe and BreweryRecipeConfig[assignment.TaskTarget] or nil
	local hasIngredients = false
	local inventoryState = nil

	if recipe and self._inventoryContext then
		inventoryState = Try(self._inventoryContext:GetPlayerInventory(userId))
		hasIngredients = WorkerInventoryUtils.HasMaterials(inventoryState, recipe.Ingredients)
	end

	local isUnlocked = recipe == nil or self._unlockContext:IsUnlocked(userId, assignment.TaskTarget)
	local hasRequiredBuilding = recipe == nil
		or self._buildingContext:HasBuildingForUser(userId, "Brewery", "BrewKettle")

	local candidate: WorkerSpecs.TBreweryTickCandidate = {
		HasRecipeAssigned = hasRecipe and recipe ~= nil,
		HasIngredients = hasIngredients,
		RecipeUnlocked = isUnlocked,
		HasRequiredBreweryBuilding = hasRequiredBuilding,
	}

	Try(WorkerSpecs.CanBrewThisTick:IsSatisfiedBy(candidate))

	return Ok({
		Recipe = recipe,
		InventoryState = inventoryState,
	})
end

return BreweryTickPolicy
