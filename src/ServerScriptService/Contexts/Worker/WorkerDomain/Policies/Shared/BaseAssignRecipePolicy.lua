--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Result = require(ReplicatedStorage.Utilities.Result)
local Ok, Try = Result.Ok, Result.Try

export type TRecipePolicyCheckContext = {
	UserId: number?,
	WorkerId: string,
	RecipeId: string,
	Entity: any,
	Assignment: any,
	Recipe: any,
	UnlockContext: any?,
	BuildingContext: any?,
	LotContext: any?,
}

export type TRecipePolicyConfig = {
	RecipeConfigTable: { [string]: any },
	Spec: any,
	PolicyUsesUserId: boolean?,
	BuildCandidate: (ctx: TRecipePolicyCheckContext) -> any,
	BuildResult: ((ctx: TRecipePolicyCheckContext) -> { [string]: any })?,
}

local BaseAssignRecipePolicy = {}
BaseAssignRecipePolicy.__index = BaseAssignRecipePolicy

function BaseAssignRecipePolicy.new(config: TRecipePolicyConfig)
	local self = setmetatable({}, BaseAssignRecipePolicy)
	self._config = config
	self._entityFactory = nil :: any
	self._registry = nil :: any
	self._unlockContext = nil :: any
	self._buildingContext = nil :: any
	self._lotContext = nil :: any
	return self
end

function BaseAssignRecipePolicy:Init(registry: any, _name: string)
	self._registry = registry
	self._entityFactory = registry:Get("WorkerEntityFactory")
end

function BaseAssignRecipePolicy:Start()
	if self._config.PolicyUsesUserId then
		self._unlockContext = self._registry:Get("UnlockContext")
		self._buildingContext = self._registry:Get("BuildingContext")
		self._lotContext = self._registry:Get("LotContext")
	end
end

function BaseAssignRecipePolicy:Check(arg1: any, arg2: string, arg3: string?)
	local userId = nil :: number?
	local workerId = arg1 :: string
	local recipeId = arg2

	if self._config.PolicyUsesUserId then
		userId = arg1 :: number
		workerId = arg2
		recipeId = arg3 :: string
	end

	local entity = self._entityFactory:FindWorkerById(workerId)
	local assignment = entity and self._entityFactory:GetAssignment(entity)
	local recipe = self._config.RecipeConfigTable[recipeId]

	local ctx: TRecipePolicyCheckContext = {
		UserId = userId,
		WorkerId = workerId,
		RecipeId = recipeId,
		Entity = entity,
		Assignment = assignment,
		Recipe = recipe,
		UnlockContext = self._unlockContext,
		BuildingContext = self._buildingContext,
		LotContext = self._lotContext,
	}

	local candidate = self._config.BuildCandidate(ctx)

	Try(self._config.Spec:IsSatisfiedBy(candidate))

	local result = {
		Entity = entity,
	}

	if self._config.BuildResult then
		for key, value in self._config.BuildResult(ctx) do
			result[key] = value
		end
	end

	return Ok(result)
end

return BaseAssignRecipePolicy
