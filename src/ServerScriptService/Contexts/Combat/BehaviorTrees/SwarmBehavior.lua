--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BehaviorTree = require(ReplicatedStorage.Utilities.BehaviorTree)
local Nodes = require(script.Parent.BehaviorNodes)

--[=[
	@class SwarmBehavior
	Builds the default swarm enemy behavior tree.
	@server
]=]
local SwarmBehavior = {}

--[=[
	@within SwarmBehavior
	Builds the default swarm enemy behavior tree.
	@return any -- Behavior tree configured for swarm enemies.
]=]
function SwarmBehavior.Create()
	return BehaviorTree:new({
		tree = BehaviorTree.Priority:new({
			nodes = {
				BehaviorTree.Sequence:new({
					nodes = {
						Nodes.Conditions.HasWaypointsCondition(),
						Nodes.Commands.LaneAdvance(),
					},
				}),
				Nodes.Commands.Idle(),
			},
		}),
	})
end

return table.freeze(SwarmBehavior)
