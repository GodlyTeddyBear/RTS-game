--!strict

--[=[
    @class UnitBehaviorConditions
    Exposes the unit behavior condition nodes used by the unit behavior graph.

    @server
]=]

local ServerStorage = game:GetService("ServerStorage")

local AI = require(ServerStorage.Utilities.ContextUtilities.AI)
local BehaviorSystem = AI.GetBehaviorSystem()

local Conditions = {
	UnitHasGoalTarget = function()
		return BehaviorSystem.Helpers.CreateConditionTask(function(task, context)
			-- Branch on the cheap navigation fact so the behavior system can gate manual movement.
			if context.Facts.HasGoalTarget then
				task:success()
				return
			end

			task:fail()
		end)
	end,
}

return table.freeze(Conditions)
