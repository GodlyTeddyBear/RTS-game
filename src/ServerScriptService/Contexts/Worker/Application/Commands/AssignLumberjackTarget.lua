--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TreeConfig = require(ReplicatedStorage.Contexts.Worker.Config.TreeConfig)
local Result = require(ReplicatedStorage.Utilities.Result)

local BaseAssignWorkerTaskCommand = require(script.Parent.Shared.BaseAssignWorkerTaskCommand)

local AssignLumberjackTarget = {}
AssignLumberjackTarget.__index = AssignLumberjackTarget

type Result<T> = Result.Result<T>

function AssignLumberjackTarget.new()
	local self = setmetatable({}, AssignLumberjackTarget)
	self._base = BaseAssignWorkerTaskCommand.new({
		PolicyName = "AssignLumberjackTargetPolicy",
		PolicyUsesUserId = true,
		SuccessEvent = "Worker:AssignLumberjackTarget:Execute",
		SuccessMessage = "Assigned lumberjack target tree and started chop action",
		LogTargetField = "treeId",
		ReturnRawTargetId = false,
		ReturnMessagePrefix = "Worker assigned to chop ",
		DurationConfigTable = TreeConfig,
		DurationFieldName = "ChopDuration",
		ResultInstanceKey = "TreeInstance",
		SlotServiceName = "ForestSlotService",
		RequireModelForSlot = true,
		AnimationState = "Chopping",
	})
	return self
end

function AssignLumberjackTarget:Init(registry: any, name: string)
	self._base:Init(registry, name)
end

function AssignLumberjackTarget:Execute(userId: number, workerId: string, treeId: string): Result<string>
	return self._base:Execute(userId, workerId, treeId)
end

return AssignLumberjackTarget
