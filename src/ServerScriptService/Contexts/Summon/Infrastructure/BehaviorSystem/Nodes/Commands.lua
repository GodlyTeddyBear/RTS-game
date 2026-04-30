--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AI = require(ReplicatedStorage.Utilities.AI)
local BehaviorSystem = AI.GetBehaviorSystem()

return table.freeze({
	SummonIdle = function()
		return BehaviorSystem.Helpers.CreateCommandTask(function(task, context)
			context.ActionFactory:SetPendingAction(context.Entity, "Summon.Idle", nil)
			task:success()
		end)
	end,
})
