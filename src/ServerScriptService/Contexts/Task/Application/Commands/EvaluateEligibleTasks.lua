--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Result = require(ReplicatedStorage.Utilities.Result)
local TaskConfig = require(ReplicatedStorage.Contexts.Task.Config.TaskConfig)

local Ok, Try = Result.Ok, Result.Try

local EvaluateEligibleTasks = {}
EvaluateEligibleTasks.__index = EvaluateEligibleTasks

function EvaluateEligibleTasks.new()
	return setmetatable({}, EvaluateEligibleTasks)
end

function EvaluateEligibleTasks:Init(registry: any, _name: string)
	self.TaskEligibilityPolicy = registry:Get("TaskEligibilityPolicy")
	self.TaskSyncService = registry:Get("TaskSyncService")
	self.TaskPersistenceService = registry:Get("TaskPersistenceService")
end

function EvaluateEligibleTasks:Execute(player: Player, userId: number): Result.Result<{ string }>
	local eligibleTaskIds = Try(self.TaskEligibilityPolicy:CollectEligibleTaskIds(player, userId))
	local startedTaskIds = {}

	for _, taskId in ipairs(eligibleTaskIds) do
		local definition = TaskConfig[taskId]
		if definition then
			self.TaskSyncService:StartTask(userId, self:_CreateTaskProgress(definition))
			table.insert(startedTaskIds, taskId)
		end
	end

	if #startedTaskIds > 0 then
		local state = self.TaskSyncService:GetTaskStateReadOnly(userId)
		if state then
			Try(self.TaskPersistenceService:SaveTaskState(player, state))
			self.TaskSyncService:HydratePlayer(player)
		end
	end

	return Ok(startedTaskIds)
end

function EvaluateEligibleTasks:_CreateTaskProgress(definition: any): any
	local objectives = {}
	for _, objective in ipairs(definition.Objectives) do
		objectives[objective.Id] = {
			Amount = 0,
		}
	end

	return {
		TaskId = definition.Id,
		Status = "Active",
		Objectives = objectives,
		StartedAt = os.time(),
	}
end

return EvaluateEligibleTasks
