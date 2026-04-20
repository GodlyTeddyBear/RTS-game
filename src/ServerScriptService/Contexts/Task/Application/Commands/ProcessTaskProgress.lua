--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Result = require(ReplicatedStorage.Utilities.Result)
local TaskConfig = require(ReplicatedStorage.Contexts.Task.Config.TaskConfig)
local TaskTypes = require(ReplicatedStorage.Contexts.Task.Types.TaskTypes)
local Errors = require(script.Parent.Parent.Parent.Errors)

local Ok, Ensure, Try = Result.Ok, Result.Ensure, Result.Try

type TTaskProgressInput = TaskTypes.TTaskProgressInput

local ProcessTaskProgress = {}
ProcessTaskProgress.__index = ProcessTaskProgress

function ProcessTaskProgress.new()
	return setmetatable({}, ProcessTaskProgress)
end

function ProcessTaskProgress:Init(registry: any, _name: string)
	self.TaskSyncService = registry:Get("TaskSyncService")
	self.TaskPersistenceService = registry:Get("TaskPersistenceService")
	self.TaskProgressCalculator = registry:Get("TaskProgressCalculator")
end

function ProcessTaskProgress:Execute(player: Player, input: TTaskProgressInput): Result.Result<boolean>
	Ensure(input.UserId > 0 and input.Amount > 0 and input.TargetId ~= "", "InvalidProgressInput", Errors.INVALID_PROGRESS_INPUT)

	local state = self.TaskSyncService:GetTaskStateReadOnly(input.UserId)
	if not state then
		return Ok(false)
	end

	local changed = false
	for taskId, taskProgress in pairs(state.Tasks) do
		local definition = TaskConfig[taskId]
		if definition then
			local updatedTask = self.TaskProgressCalculator:ApplyProgress(definition, taskProgress, input)
			if updatedTask then
				self.TaskSyncService:UpdateTask(input.UserId, taskId, updatedTask)
				changed = true
			end
		end
	end

	if changed then
		local updatedState = self.TaskSyncService:GetTaskStateReadOnly(input.UserId)
		if updatedState then
			Try(self.TaskPersistenceService:SaveTaskState(player, updatedState))
			self.TaskSyncService:HydratePlayer(player)
		end
	end

	return Ok(changed)
end

return ProcessTaskProgress
