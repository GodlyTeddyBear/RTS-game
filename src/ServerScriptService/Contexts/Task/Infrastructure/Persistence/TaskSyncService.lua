--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local BaseSyncService = require(ReplicatedStorage.Utilities.BaseSyncService)
local SharedAtoms = require(ReplicatedStorage.Contexts.Task.Sync.SharedAtoms)
local TaskTypes = require(ReplicatedStorage.Contexts.Task.Types.TaskTypes)

type TTaskState = TaskTypes.TTaskState
type TPlayerTaskProgress = TaskTypes.TPlayerTaskProgress

local DEFAULT_STATE: TTaskState = {
	Tasks = {},
}

local TaskSyncService = setmetatable({}, { __index = BaseSyncService })
TaskSyncService.__index = TaskSyncService
TaskSyncService.AtomKey = "tasks"
TaskSyncService.BlinkEventName = "SyncTasks"
TaskSyncService.CreateAtom = SharedAtoms.CreateServerAtom

local function _DeepClone(value: any): any
	if type(value) ~= "table" then
		return value
	end

	local clone = {}
	for key, nested in pairs(value) do
		clone[key] = _DeepClone(nested)
	end
	return clone
end

function TaskSyncService.new()
	return setmetatable({}, TaskSyncService)
end

function TaskSyncService:Init(registry: any, name: string)
	BaseSyncService.Init(self, registry, name)

	if self.Cleanup then
		self.Cleanup()
	end

	self.Cleanup = self.Syncer:connect(function(player: Player, _: any)
		local userId = player.UserId
		local allTasks = self.Atom()
		local playerTasks = allTasks[userId]

		self.BlinkServer.SyncTasks.Fire(player, {
			type = "init",
			data = {
				tasks = playerTasks or _DeepClone(DEFAULT_STATE),
			},
		})
	end)
end

function TaskSyncService:GetTaskStateReadOnly(userId: number): TTaskState?
	return self:GetReadOnly(userId)
end

function TaskSyncService:IsPlayerLoaded(userId: number): boolean
	return self.Atom()[userId] ~= nil
end

function TaskSyncService:GetTasksAtom()
	return self:GetAtom()
end

function TaskSyncService:LoadUserTasks(userId: number, state: TTaskState)
	self:LoadUserData(userId, state)
end

function TaskSyncService:RemoveUserTasks(userId: number)
	self:RemoveUserData(userId)
end

function TaskSyncService:StartTask(userId: number, taskProgress: TPlayerTaskProgress)
	self.Atom(function(current)
		local updated = table.clone(current)
		local userState = table.clone(updated[userId] or DEFAULT_STATE)
		local tasks = table.clone(userState.Tasks or {})
		tasks[taskProgress.TaskId] = taskProgress
		userState.Tasks = tasks
		updated[userId] = userState
		return updated
	end)
end

function TaskSyncService:UpdateTask(userId: number, taskId: string, taskProgress: TPlayerTaskProgress)
	self.Atom(function(current)
		local updated = table.clone(current)
		local userState = table.clone(updated[userId])
		userState.Tasks = table.clone(userState.Tasks)
		userState.Tasks[taskId] = taskProgress
		updated[userId] = userState
		return updated
	end)
end

return TaskSyncService
