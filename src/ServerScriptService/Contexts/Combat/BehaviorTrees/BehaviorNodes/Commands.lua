--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BehaviorTree = require(ReplicatedStorage.Utilities.BehaviorTree)

--[=[
	@class Commands
	Builds combat behavior tree action nodes.
	@server
]=]
local Commands = {}

--[=[
	@within Commands
	Returns the lane-advance action node that queues movement for the executor pipeline.
	@return any -- Behavior tree task that queues lane advancement.
]=]
function Commands.LaneAdvance()
	return BehaviorTree.Task:new({
		run = function(task, ctx)
			ctx.EnemyEntityFactory:SetPendingAction(ctx.Entity, "LaneAdvance", nil)
			task:success()
	end,
	})
end

--[=[
	@within Commands
	Returns the idle action node used as a fallback when no movement is available.
	@return any -- Behavior tree task that keeps the enemy idle.
]=]
function Commands.Idle()
	return BehaviorTree.Task:new({
		run = function(task, ctx)
			ctx.EnemyEntityFactory:SetPendingAction(ctx.Entity, "Idle", nil)
			task:success()
		end,
	})
end

return Commands
