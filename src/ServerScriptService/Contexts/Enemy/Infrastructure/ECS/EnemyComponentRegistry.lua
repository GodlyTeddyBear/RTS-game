--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local JECS = require(ReplicatedStorage.Packages.JECS)

--[=[
	@class EnemyComponentRegistry
	Registers enemy ECS components and exposes ids for other modules.
	@server
]=]
local EnemyComponentRegistry = {}
EnemyComponentRegistry.__index = EnemyComponentRegistry

function EnemyComponentRegistry.new()
	local self = setmetatable({}, EnemyComponentRegistry)
	self._components = nil
	return self
end

local function _nameComponent(world: any, componentId: number, name: string)
	world:set(componentId, JECS.Name, name)
end

function EnemyComponentRegistry:Init(registry: any, _name: string)
	local world = registry:Get("World")

	local health = world:component()
	local position = world:component()
	local role = world:component()
	local pathState = world:component()
	local modelRef = world:component()
	local identity = world:component()
	local behaviorTree = world:component()
	local combatAction = world:component()
	local attackCooldown = world:component()
	local behaviorConfig = world:component()
	local aliveTag = world:entity()
	local dirtyTag = world:entity()
	local goalReachedTag = world:entity()

	_nameComponent(world, health, "Enemy.Health")
	_nameComponent(world, position, "Enemy.Position")
	_nameComponent(world, role, "Enemy.Role")
	_nameComponent(world, pathState, "Enemy.PathState")
	_nameComponent(world, modelRef, "Enemy.ModelRef")
	_nameComponent(world, identity, "Enemy.Identity")
	_nameComponent(world, behaviorTree, "Enemy.BehaviorTree")
	_nameComponent(world, combatAction, "Enemy.CombatAction")
	_nameComponent(world, attackCooldown, "Enemy.AttackCooldown")
	_nameComponent(world, behaviorConfig, "Enemy.BehaviorConfig")
	_nameComponent(world, aliveTag, "Enemy.Alive")
	_nameComponent(world, dirtyTag, "Enemy.Dirty")
	_nameComponent(world, goalReachedTag, "Enemy.GoalReached")

	self._components = table.freeze({
		Health = health,
		Position = position,
		Role = role,
		PathState = pathState,
		ModelRef = modelRef,
		Identity = identity,
		BehaviorTree = behaviorTree,
		CombatAction = combatAction,
		AttackCooldown = attackCooldown,
		BehaviorConfig = behaviorConfig,
		AliveTag = aliveTag,
		DirtyTag = dirtyTag,
		GoalReachedTag = goalReachedTag,
	})
end

function EnemyComponentRegistry:GetComponents()
	return self._components
end

return EnemyComponentRegistry
