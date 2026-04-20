--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RecipeConfig = require(ReplicatedStorage.Contexts.Forge.Config.RecipeConfig)
local ForgeStationConfig = require(ReplicatedStorage.Contexts.Forge.Config.ForgeStationConfig)
local WorkerSpecs = require(script.Parent.Parent.Specs.WorkerSpecs)
local WorkerInventoryUtils = require(script.Parent.Parent.Services.WorkerInventoryUtils)
local Result = require(ReplicatedStorage.Utilities.Result)

local Ok = Result.Ok
local Try = Result.Try

local ForgeTickPolicy = {}
ForgeTickPolicy.__index = ForgeTickPolicy

function ForgeTickPolicy.new()
	return setmetatable({}, ForgeTickPolicy)
end

function ForgeTickPolicy:Init(registry: any, _name: string)
	self._registry = registry
end

function ForgeTickPolicy:Start()
	self._inventoryContext = self._registry:Get("InventoryContext")
	self._unlockContext = self._registry:Get("UnlockContext")
	self._buildingContext = self._registry:Get("BuildingContext")
end

function ForgeTickPolicy:Check(assignment: any, userId: number)
	local hasRecipe = assignment.TaskTarget ~= nil
	local recipe = hasRecipe and RecipeConfig[assignment.TaskTarget] or nil
	local hasIngredients = false
	local inventoryState = nil

	if recipe and self._inventoryContext then
		inventoryState = Try(self._inventoryContext:GetPlayerInventory(userId))
		hasIngredients = WorkerInventoryUtils.HasMaterials(inventoryState, recipe.Ingredients)
	end

	local stationInfo = recipe and ForgeStationConfig[recipe.ForgeStation] or nil
	local requiredBuildingType = stationInfo and stationInfo.BuildingType or nil
	local isUnlocked = recipe == nil or self._unlockContext:IsUnlocked(userId, assignment.TaskTarget)
	local hasRequiredBuilding = recipe == nil
		or (requiredBuildingType ~= nil and self._buildingContext:HasBuildingForUser(userId, "Forge", requiredBuildingType))
	local isInstant = recipe == nil
		or recipe.ProcessDurationSeconds == nil
		or recipe.ProcessDurationSeconds <= 0

	local candidate: WorkerSpecs.TForgeTickCandidate = {
		HasRecipeAssigned = hasRecipe and recipe ~= nil,
		HasIngredients = hasIngredients,
		IsInstantForgeRecipe = isInstant,
		RecipeUnlocked = isUnlocked,
		HasRequiredForgeBuilding = hasRequiredBuilding,
	}

	Try(WorkerSpecs.CanForgeThisTick:IsSatisfiedBy(candidate))

	return Ok({
		Recipe = recipe,
		InventoryState = inventoryState,
	})
end

return ForgeTickPolicy
