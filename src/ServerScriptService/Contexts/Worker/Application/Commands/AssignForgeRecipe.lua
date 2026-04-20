--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Result = require(ReplicatedStorage.Utilities.Result)
local BaseAssignWorkerTaskCommand = require(script.Parent.Shared.BaseAssignWorkerTaskCommand)

local AssignForgeRecipe = {}
AssignForgeRecipe.__index = AssignForgeRecipe

type Result<T> = Result.Result<T>

function AssignForgeRecipe.new()
	local self = setmetatable({}, AssignForgeRecipe)
	self._base = BaseAssignWorkerTaskCommand.new({
		PolicyName = "AssignForgeRecipePolicy",
		PolicyUsesUserId = true,
		SuccessEvent = "Worker:AssignForgeRecipe:Execute",
		SuccessMessage = "Assigned forge recipe to worker task target",
		LogTargetField = "recipeId",
		ReturnRawTargetId = true,
		ResultInstanceKey = "ForgeStationInstance",
		SlotServiceName = "ForgeStationSlotService",
		SlotTargetIdFieldName = "SlotTargetId",
	})
	return self
end

function AssignForgeRecipe:Init(registry: any, name: string)
	self._base:Init(registry, name)
end

function AssignForgeRecipe:Execute(userId: number, workerId: string, recipeId: string): Result<string>
	return self._base:Execute(userId, workerId, recipeId)
end

return AssignForgeRecipe
