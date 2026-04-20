--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Result = require(ReplicatedStorage.Utilities.Result)
local BaseAssignWorkerTaskCommand = require(script.Parent.Shared.BaseAssignWorkerTaskCommand)

local AssignTailoringRecipe = {}
AssignTailoringRecipe.__index = AssignTailoringRecipe

type Result<T> = Result.Result<T>

function AssignTailoringRecipe.new()
	local self = setmetatable({}, AssignTailoringRecipe)
	self._base = BaseAssignWorkerTaskCommand.new({
		PolicyName = "AssignTailoringRecipePolicy",
		PolicyUsesUserId = false,
		SuccessEvent = "Worker:AssignTailoringRecipe:Execute",
		SuccessMessage = "Assigned tailoring recipe to worker task target",
		LogTargetField = "recipeId",
		ReturnRawTargetId = true,
	})
	return self
end

function AssignTailoringRecipe:Init(registry: any, name: string)
	self._base:Init(registry, name)
end

function AssignTailoringRecipe:Execute(userId: number, workerId: string, recipeId: string): Result<string>
	return self._base:Execute(userId, workerId, recipeId)
end

return AssignTailoringRecipe
