--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Result = require(ReplicatedStorage.Utilities.Result)
local TaskTypes = require(ReplicatedStorage.Contexts.Task.Types.TaskTypes)

local Ok, Ensure = Result.Ok, Result.Ensure

type TTaskState = TaskTypes.TTaskState

local GetTaskState = {}
GetTaskState.__index = GetTaskState

function GetTaskState.new()
	return setmetatable({}, GetTaskState)
end

function GetTaskState:Init(registry: any, _name: string)
	self.TaskSyncService = registry:Get("TaskSyncService")
end

function GetTaskState:Execute(userId: number): Result.Result<TTaskState>
	Ensure(userId > 0, "InvalidUserId", "Invalid user ID")
	return Ok(self.TaskSyncService:GetTaskStateReadOnly(userId) or {
		Tasks = {},
	})
end

return GetTaskState
