--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local BaseSyncClient = require(ReplicatedStorage.Utilities.BaseSyncClient)
local SharedAtoms = require(ReplicatedStorage.Contexts.Task.Sync.SharedAtoms)

local TaskSyncClient = setmetatable({}, { __index = BaseSyncClient })
TaskSyncClient.__index = TaskSyncClient

function TaskSyncClient.new(BlinkClient: any)
	local self = BaseSyncClient.new(BlinkClient, "SyncTasks", "tasks", SharedAtoms.CreateClientAtom)
	return setmetatable(self, TaskSyncClient)
end

function TaskSyncClient:GetTaskStateAtom()
	return self:GetAtom()
end

return TaskSyncClient
