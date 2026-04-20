--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Result = require(ReplicatedStorage.Utilities.Result)
local Ok, Try = Result.Ok, Result.Try
local WorkerInventoryUtils = require(script.Parent.Parent.Parent.Services.WorkerInventoryUtils)

export type TRecipeTickPolicyCheckContext = {
	HasRecipeAssigned: boolean,
	Recipe: any,
	HasIngredients: boolean,
}

export type TRecipeTickPolicyConfig = {
	RecipeConfigTable: { [string]: any },
	Spec: any,
	BuildCandidate: (ctx: TRecipeTickPolicyCheckContext) -> any,
}

local BaseRecipeTickPolicy = {}
BaseRecipeTickPolicy.__index = BaseRecipeTickPolicy

function BaseRecipeTickPolicy.new(config: TRecipeTickPolicyConfig)
	local self = setmetatable({}, BaseRecipeTickPolicy)
	self._config = config
	self._registry = nil :: any
	self._inventoryContext = nil :: any
	return self
end

function BaseRecipeTickPolicy:Init(registry: any, _name: string)
	self._registry = registry
end

function BaseRecipeTickPolicy:Start()
	self._inventoryContext = self._registry:Get("InventoryContext")
end

function BaseRecipeTickPolicy:Check(assignment: any, userId: number)
	local hasRecipe = assignment.TaskTarget ~= nil
	local recipe = hasRecipe and self._config.RecipeConfigTable[assignment.TaskTarget] or nil
	local hasIngredients = false
	local inventoryState = nil

	if recipe and self._inventoryContext then
		inventoryState = Try(self._inventoryContext:GetPlayerInventory(userId))
		hasIngredients = WorkerInventoryUtils.HasMaterials(inventoryState, recipe.Ingredients)
	end

	local candidate = self._config.BuildCandidate({
		HasRecipeAssigned = hasRecipe and recipe ~= nil,
		Recipe = recipe,
		HasIngredients = hasIngredients,
	})

	local specResult = self._config.Spec:IsSatisfiedBy(candidate)
	if not specResult.success then
		return specResult
	end

	return Ok({
		Recipe = recipe,
		InventoryState = inventoryState,
	})
end

return BaseRecipeTickPolicy
