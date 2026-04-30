--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AI = require(ReplicatedStorage.Utilities.AI)
local BehaviorSystem = AI.GetBehaviorSystem()

local Commands = {
	UnitIdle = function()
		return BehaviorSystem.Helpers.CreateCommandTask(function(task, context)
			context.ActionFactory:SetPendingAction(context.Entity, "Unit.Idle", nil)
			task:success()
		end)
	end,
}

return table.freeze(Commands)
