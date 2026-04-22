--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BehaviorTree = require(ReplicatedStorage.Utilities.BehaviorTree)
local Nodes = require(script.Parent.BehaviorNodes)

--[=[
	@class StructureBehavior
	Builds the default structure combat behavior tree.
	@server
]=]
local StructureBehavior = {}

function StructureBehavior.Create()
	return BehaviorTree:new({
		tree = BehaviorTree.Priority:new({
			nodes = {
				BehaviorTree.Sequence:new({
					nodes = {
						Nodes.Conditions.HasEnemyTargetInRangeCondition(),
						Nodes.Commands.StructureAttack(),
					},
				}),
				Nodes.Commands.Idle(),
			},
		}),
	})
end

return table.freeze(StructureBehavior)
