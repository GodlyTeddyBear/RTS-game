--!strict

local ServerStorage = game:GetService("ServerStorage")

local AI = require(ServerStorage.Utilities.ContextUtilities.AI)
local BehaviorSystem = AI.GetBehaviorSystem()

local Conditions = {
	HasGoalTarget = function()
		return BehaviorSystem.Helpers.CreateConditionTask(function(task, context)
			if context.Facts.HasGoalTarget then
				task:success()
				return
			end

			task:fail()
		end)
	end,
}

return table.freeze(Conditions)
