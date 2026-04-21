--!strict

local SwarmBehavior = require(script.Parent.Parent.Parent.BehaviorTrees.SwarmBehavior)
local TankBehavior = require(script.Parent.Parent.Parent.BehaviorTrees.TankBehavior)

local BEHAVIOR_MAP = {
	swarm = SwarmBehavior,
	tank = TankBehavior,
}

--[=[
	@class BehaviorTreeFactory
	Creates role-specific combat behavior trees for enemy entities.
	@server
]=]
local BehaviorTreeFactory = {}
BehaviorTreeFactory.__index = BehaviorTreeFactory

-- Creates a new behavior tree factory.
function BehaviorTreeFactory.new()
	return setmetatable({}, BehaviorTreeFactory)
end

-- No-op initialization hook kept for registry symmetry.
function BehaviorTreeFactory:Init(_registry: any, _name: string)
end

-- Creates a tree for the requested enemy role, falling back to swarm behavior.
function BehaviorTreeFactory:CreateTree(role: string)
	local builder = BEHAVIOR_MAP[role] or SwarmBehavior
	return builder.Create()
end

return BehaviorTreeFactory
