--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local AI = require(ServerStorage.Utilities.ContextUtilities.AI)
local BehaviorSystem = AI.GetBehaviorSystem()

return table.freeze({
	SummonIdle = function()
		return BehaviorSystem.Helpers.CreateCommandTask(function(task, context)
			context.ActionFactory:SetPendingAction(context.Entity, "Summon.Idle", nil)
			task:success()
		end)
	end,
})
