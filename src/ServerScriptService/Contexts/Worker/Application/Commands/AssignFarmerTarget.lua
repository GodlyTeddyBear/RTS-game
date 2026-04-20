--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CropConfig = require(ReplicatedStorage.Contexts.Worker.Config.CropConfig)
local Result = require(ReplicatedStorage.Utilities.Result)

local BaseAssignWorkerTaskCommand = require(script.Parent.Shared.BaseAssignWorkerTaskCommand)

local AssignFarmerTarget = {}
AssignFarmerTarget.__index = AssignFarmerTarget

type Result<T> = Result.Result<T>

function AssignFarmerTarget.new()
	local self = setmetatable({}, AssignFarmerTarget)
	self._base = BaseAssignWorkerTaskCommand.new({
		PolicyName = "AssignFarmerTargetPolicy",
		PolicyUsesUserId = true,
		SuccessEvent = "Worker:AssignFarmerTarget:Execute",
		SuccessMessage = "Assigned farmer target crop and started growth action",
		LogTargetField = "cropId",
		ReturnRawTargetId = false,
		ReturnMessagePrefix = "Worker assigned to grow ",
		DurationConfigTable = CropConfig,
		DurationFieldName = "GrowDuration",
	})
	return self
end

function AssignFarmerTarget:Init(registry: any, name: string)
	self._base:Init(registry, name)
end

function AssignFarmerTarget:Execute(userId: number, workerId: string, cropId: string): Result<string>
	return self._base:Execute(userId, workerId, cropId)
end

return AssignFarmerTarget
