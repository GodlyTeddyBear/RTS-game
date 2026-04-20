--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Result = require(ReplicatedStorage.Utilities.Result)
local TaskConfig = require(ReplicatedStorage.Contexts.Task.Config.TaskConfig)
local TaskSpecs = require(script.Parent.Parent.Specs.TaskSpecs)

local Ok, Try = Result.Ok, Result.Try

local ClaimTaskRewardPolicy = {}
ClaimTaskRewardPolicy.__index = ClaimTaskRewardPolicy

function ClaimTaskRewardPolicy.new()
	return setmetatable({}, ClaimTaskRewardPolicy)
end

function ClaimTaskRewardPolicy:Init(registry: any, _name: string)
	self.TaskSyncService = registry:Get("TaskSyncService")
end

function ClaimTaskRewardPolicy:Check(userId: number, taskId: string): Result.Result<any>
	local state = self.TaskSyncService:GetTaskStateReadOnly(userId)
	local taskProgress = state and state.Tasks[taskId] or nil
	local definition = TaskConfig[taskId]

	Try(TaskSpecs.CanClaimTask:IsSatisfiedBy({
		TaskExists = definition ~= nil and taskProgress ~= nil,
		Status = taskProgress and taskProgress.Status or nil,
	}))

	return Ok({
		State = state,
		TaskProgress = taskProgress,
		Definition = definition,
	})
end

return ClaimTaskRewardPolicy
