--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PlantConfig = require(ReplicatedStorage.Contexts.Worker.Config.PlantConfig)
local Result = require(ReplicatedStorage.Utilities.Result)

local BaseAssignWorkerTaskCommand = require(script.Parent.Shared.BaseAssignWorkerTaskCommand)

local AssignHerbalistTarget = {}
AssignHerbalistTarget.__index = AssignHerbalistTarget

type Result<T> = Result.Result<T>

function AssignHerbalistTarget.new()
	local self = setmetatable({}, AssignHerbalistTarget)
	self._base = BaseAssignWorkerTaskCommand.new({
		PolicyName = "AssignHerbalistTargetPolicy",
		PolicyUsesUserId = true,
		SuccessEvent = "Worker:AssignHerbalistTarget:Execute",
		SuccessMessage = "Assigned herbalist target plant and started harvest action",
		LogTargetField = "plantId",
		ReturnRawTargetId = false,
		ReturnMessagePrefix = "Worker assigned to harvest ",
		DurationConfigTable = PlantConfig,
		DurationFieldName = "HarvestDuration",
		ResultInstanceKey = "PlantInstance",
		SlotServiceName = "GardenSlotService",
		RequireModelForSlot = true,
	})
	return self
end

function AssignHerbalistTarget:Init(registry: any, name: string)
	self._base:Init(registry, name)
end

function AssignHerbalistTarget:Execute(userId: number, workerId: string, plantId: string): Result<string>
	return self._base:Execute(userId, workerId, plantId)
end

return AssignHerbalistTarget
