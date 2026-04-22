--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BehaviorTree = require(ReplicatedStorage.Utilities.BehaviorTree)
local Nodes = require(script.Parent.BehaviorNodes)

--[=[
	@class TankBehavior
	Builds the tank enemy behavior tree.
	@server
]=]
local TankBehavior = {}

--[=[
	@within TankBehavior
	Builds the tank enemy behavior tree.
	@return any -- Behavior tree configured for tank enemies.
]=]
function TankBehavior.Create()
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

return table.freeze(TankBehavior)
