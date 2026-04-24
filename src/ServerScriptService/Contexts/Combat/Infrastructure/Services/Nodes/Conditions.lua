--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BehaviorSystem = require(ReplicatedStorage.Utilities.BehaviorSystem)

--[=[
	@class CombatBehaviorConditions
	Provides Combat-local BehaviorSystem condition node builders.
	@server
]=]
local Conditions = {
	HasWaypoints = function()
		return BehaviorSystem.Helpers.CreateConditionTask(function(task, context)
			if context.Facts.HasWaypoints then
				task:success()
				return
			end

			task:fail()
		end)
	end,
	HasStructureTargetInRange = function()
		return BehaviorSystem.Helpers.CreateConditionTask(function(task, context)
			if context.Facts.TargetStructureEntity ~= nil then
				task:success()
				return
			end

			task:fail()
		end)
	end,
	HasEnemyTargetInRange = function()
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
