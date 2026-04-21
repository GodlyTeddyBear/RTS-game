--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BehaviorTree = require(ReplicatedStorage.Utilities.BehaviorTree)

--[=[
	@class Conditions
	Builds combat behavior tree condition nodes.
]=]
local Conditions = {}

-- Returns a condition node that succeeds when the enemy has lane waypoints.
function Conditions.HasWaypointsCondition()
	return BehaviorTree.Task:new({
		run = function(task, ctx)
			if ctx.Facts.HasWaypoints then
				task:success()
				return
			end
			task:fail()
		end,
	})
end

-- Returns a condition node reserved for future flee logic.
function Conditions.ShouldFleeCondition()
	return BehaviorTree.Task:new({
		run = function(task, ctx)
			if ctx.Facts.ShouldFlee then
				task:success()
				return
			end
			task:fail()
		end,
	})
end

return Conditions
