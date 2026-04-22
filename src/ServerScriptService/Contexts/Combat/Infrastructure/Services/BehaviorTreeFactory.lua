--!strict

local SwarmBehavior = require(script.Parent.Parent.Parent.BehaviorTrees.SwarmBehavior)
local TankBehavior = require(script.Parent.Parent.Parent.BehaviorTrees.TankBehavior)
local StructureBehavior = require(script.Parent.Parent.Parent.BehaviorTrees.StructureBehavior)

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

--[=[
	@within BehaviorTreeFactory
	Creates a new behavior tree factory.
	@return BehaviorTreeFactory -- Factory instance used to build combat trees.
]=]
function BehaviorTreeFactory.new()
	return setmetatable({}, BehaviorTreeFactory)
end

--[=[
	@within BehaviorTreeFactory
	No-op initialization hook kept for registry symmetry.
	@param _registry any -- Registry instance supplied by the context bootstrap.
	@param _name string -- Registry key used to register the service.
]=]
function BehaviorTreeFactory:Init(_registry: any, _name: string)
end

--[=[
	@within BehaviorTreeFactory
	Creates a tree for the requested enemy role, falling back to swarm behavior.
	@param role string -- Enemy role name used to pick the tree builder.
	@return any -- Behavior tree created for the requested role.
]=]
function BehaviorTreeFactory:CreateTree(role: string)
	local builder = BEHAVIOR_MAP[role] or SwarmBehavior
	return builder.Create()
end

function BehaviorTreeFactory:CreateStructureTree()
	return StructureBehavior.Create()
end

return BehaviorTreeFactory
