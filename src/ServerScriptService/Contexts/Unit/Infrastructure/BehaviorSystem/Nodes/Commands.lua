--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local AI = require(ServerStorage.Utilities.ContextUtilities.AI)
local BehaviorSystem = AI.GetBehaviorSystem()

local Commands = {
	Idle = function()
		return BehaviorSystem.Helpers.CreateCommandTask(function(task, context)
			context.ActionFactory:SetPendingAction(context.Entity, "Idle", nil)
			task:success()
		end)
	end,
	ManualMove = function()
		return BehaviorSystem.Helpers.CreateCommandTask(function(task, context)
			context.ActionFactory:SetPendingAction(context.Entity, "ManualMove", nil)
			task:success()
		end)
	end,
}

return table.freeze(Commands)
