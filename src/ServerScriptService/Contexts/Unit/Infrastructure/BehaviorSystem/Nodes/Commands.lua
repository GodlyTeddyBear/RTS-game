--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local AI = require(ServerStorage.Utilities.ContextUtilities.AI)
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
