--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BehaviorTree = require(ReplicatedStorage.Utilities.BehaviorTree)

--[=[
	@class Conditions
	Builds combat behavior tree condition nodes.
	@server
]=]
local Conditions = {}

--[=[
	@within Conditions
	Returns a condition node that succeeds when the enemy has lane waypoints.
	@return any -- Behavior tree task that validates lane availability.
]=]
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

--[=[
	@within Conditions
	Returns a condition node reserved for future flee logic.
	@return any -- Behavior tree task that checks flee pressure.
]=]
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

--[=[
	@within Conditions
	Returns a condition node that succeeds when an enemy can melee a nearby structure.
	@return any -- Behavior tree task that validates structure target availability.
]=]
function Conditions.HasStructureTargetInRangeCondition()
	return BehaviorTree.Task:new({
		run = function(task, ctx)
			if ctx.Facts.TargetStructureEntity ~= nil then
				task:success()
				return
			end
			task:fail()
		end,
	})
end

--[=[
	@within Conditions
	Returns a condition node that succeeds when a structure can attack an enemy.
	@return any -- Behavior tree task that validates enemy target availability.
]=]
function Conditions.HasEnemyTargetInRangeCondition()
	return BehaviorTree.Task:new({
		run = function(task, ctx)
			if ctx.Facts.TargetEnemyEntity ~= nil then
				task:success()
				return
			end
			task:fail()
		end,
	})
end

return Conditions
