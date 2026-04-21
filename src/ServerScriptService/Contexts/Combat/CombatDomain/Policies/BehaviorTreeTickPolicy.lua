--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Result = require(ReplicatedStorage.Utilities.Result)

local Ok = Result.Ok
local Err = Result.Err

--[=[
	@class BehaviorTreeTickPolicy
	Gates behavior tree ticks until the action state and tick interval are ready.
	@server
]=]
local BehaviorTreeTickPolicy = {}
BehaviorTreeTickPolicy.__index = BehaviorTreeTickPolicy

-- Creates a new behavior tree tick policy.
function BehaviorTreeTickPolicy.new()
	return setmetatable({}, BehaviorTreeTickPolicy)
end

-- Resolves the enemy entity factory used to read combat action and behavior tree state.
function BehaviorTreeTickPolicy:Init(registry: any, _name: string)
	self._enemyEntityFactory = registry:Get("EnemyEntityFactory")
end

-- Returns the stored behavior tree when the entity is allowed to evaluate this frame.
function BehaviorTreeTickPolicy:Check(entity: number, currentTime: number): Result.Result<any>
	local combatAction = self._enemyEntityFactory:GetCombatAction(entity)
	if combatAction and combatAction.ActionState == "Committed" then
		return Err("Committed", "Action is committed")
	end

	local behaviorTree = self._enemyEntityFactory:GetBehaviorTree(entity)
	if not behaviorTree then
		return Err("NoBT", "Behavior tree not assigned")
	end

	if currentTime - behaviorTree.LastTickTime < behaviorTree.TickInterval then
		return Err("IntervalNotReady", "Tick interval not elapsed")
	end

	return Ok({
		BehaviorTree = behaviorTree,
	})
end

return BehaviorTreeTickPolicy
