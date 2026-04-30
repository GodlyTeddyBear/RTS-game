--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AI = require(ReplicatedStorage.Utilities.AI)
local BehaviorSystem = AI.GetBehaviorSystem()

local Conditions = {
	StructureHasEnemyTargetInRange = function()
		return BehaviorSystem.Helpers.CreateConditionTask(function(task, context)
			if context.Facts.TargetEnemyEntity ~= nil then
				task:success()
				return
			end

			task:fail()
		end)
	end,
}

return table.freeze(Conditions)
