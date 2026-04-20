--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Result = require(ReplicatedStorage.Utilities.Result)
local BaseAssignWorkerTaskCommand = require(script.Parent.Shared.BaseAssignWorkerTaskCommand)

local AssignBreweryRecipe = {}
AssignBreweryRecipe.__index = AssignBreweryRecipe

type Result<T> = Result.Result<T>

function AssignBreweryRecipe.new()
	local self = setmetatable({}, AssignBreweryRecipe)
	self._base = BaseAssignWorkerTaskCommand.new({
		PolicyName = "AssignBreweryRecipePolicy",
		PolicyUsesUserId = true,
		SuccessEvent = "Worker:AssignBreweryRecipe:Execute",
		SuccessMessage = "Assigned brewery recipe to worker task target",
		LogTargetField = "recipeId",
		ReturnRawTargetId = true,
		ResultInstanceKey = "BreweryStationInstance",
		SlotServiceName = "BreweryStationSlotService",
		SlotTargetIdFieldName = "SlotTargetId",
	})
	return self
end

function AssignBreweryRecipe:Init(registry: any, name: string)
	self._base:Init(registry, name)
end

function AssignBreweryRecipe:Execute(userId: number, workerId: string, recipeId: string): Result<string>
	return self._base:Execute(userId, workerId, recipeId)
end

return AssignBreweryRecipe
