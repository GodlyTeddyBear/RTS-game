--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages.Knit)
local Registry = require(ReplicatedStorage.Utilities.Registry)
local BlinkClient = require(ReplicatedStorage.Network.Generated.TaskSyncClient)

local TaskSyncClient = require(script.Parent.Infrastructure.TaskSyncClient)

local TaskController = Knit.CreateController({
	Name = "TaskController",
})

function TaskController:KnitInit()
	local registry = Registry.new("Client")
	self.Registry = registry

	self.SyncService = TaskSyncClient.new(BlinkClient)
	registry:Register("TaskSyncClient", self.SyncService, "Infrastructure")
	registry:InitAll()
end

function TaskController:KnitStart()
	self.TaskContext = Knit.GetService("TaskContext")
	self.Registry:StartOrdered({ "Infrastructure" })

	task.delay(0.3, function()
		self:RequestTaskState()
	end)
end

function TaskController:GetTaskStateAtom()
	return self.SyncService:GetTaskStateAtom()
end

function TaskController:RequestTaskState()
	return self.TaskContext:RequestTaskState()
		:catch(function(err)
			warn("[TaskController:RequestTaskState]", err.type, err.message)
		end)
end

function TaskController:ClaimTaskReward(taskId: string)
	return self.TaskContext:ClaimTaskReward(taskId)
		:catch(function(err)
			warn("[TaskController:ClaimTaskReward]", err.type, err.message)
		end)
end

return TaskController
