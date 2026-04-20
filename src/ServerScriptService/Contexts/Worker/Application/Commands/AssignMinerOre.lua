--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local OreConfig = require(ReplicatedStorage.Contexts.Worker.Config.OreConfig)
local Result = require(ReplicatedStorage.Utilities.Result)

local BaseAssignWorkerTaskCommand = require(script.Parent.Shared.BaseAssignWorkerTaskCommand)

local AssignMinerOre = {}
AssignMinerOre.__index = AssignMinerOre

type Result<T> = Result.Result<T>

function AssignMinerOre.new()
	local self = setmetatable({}, AssignMinerOre)
	self._base = BaseAssignWorkerTaskCommand.new({
		PolicyName = "AssignMinerOrePolicy",
		PolicyUsesUserId = true,
		SuccessEvent = "Worker:AssignMinerOre:Execute",
		SuccessMessage = "Assigned miner target ore and started mining action",
		LogTargetField = "oreId",
		ReturnRawTargetId = false,
		ReturnMessagePrefix = "Worker assigned to mine ",
		DurationConfigTable = OreConfig,
		DurationFieldName = "MiningDuration",
		ResultInstanceKey = "OreInstance",
		SlotServiceName = "MiningSlotService",
		RequireModelForSlot = false,
	})
	return self
end

function AssignMinerOre:Init(registry: any, name: string)
	self._base:Init(registry, name)
end

function AssignMinerOre:Execute(userId: number, workerId: string, oreId: string): Result<string>
	return self._base:Execute(userId, workerId, oreId)
end

return AssignMinerOre
