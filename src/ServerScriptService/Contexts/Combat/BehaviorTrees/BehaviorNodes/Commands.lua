--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BehaviorTree = require(ReplicatedStorage.Utilities.BehaviorTree)

--[=[
	@class Commands
	Builds combat behavior tree action nodes.
]=]
local Commands = {}

-- Returns the lane-advance action node that queues movement for the executor pipeline.
function Commands.LaneAdvance()
	return BehaviorTree.Task:new({
		run = function(task, ctx)
			ctx.EnemyEntityFactory:SetPendingAction(ctx.Entity, "LaneAdvance", nil)
			task:success()
		end,
	})
end

-- Returns the idle action node used as a fallback when no movement is available.
function Commands.Idle()
	return BehaviorTree.Task:new({
		run = function(task, ctx)
			ctx.EnemyEntityFactory:SetPendingAction(ctx.Entity, "Idle", nil)
			task:success()
		end,
	})
end

return Commands
