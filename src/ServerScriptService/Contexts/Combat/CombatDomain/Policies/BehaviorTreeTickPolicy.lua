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

--[=[
	@within BehaviorTreeTickPolicy
	Creates a new behavior tree tick policy.
	@return BehaviorTreeTickPolicy -- Policy instance used to gate BT updates.
]=]
function BehaviorTreeTickPolicy.new()
	return setmetatable({}, BehaviorTreeTickPolicy)
end

--[=[
	@within BehaviorTreeTickPolicy
	Resolves the enemy entity factory used to read combat action and behavior tree state.
	@param _registry any -- Registry instance supplied by the context bootstrap.
	@param _name string -- Registry key used to register the policy.
]=]
function BehaviorTreeTickPolicy:Init(_registry: any, _name: string)
end

--[=[
	@within BehaviorTreeTickPolicy
	Stores the enemy entity factory needed by the policy.
	@param registry any -- Registry instance used to resolve dependencies.
	@param _name string -- Registry key used to register the policy.
]=]
function BehaviorTreeTickPolicy:Start(registry: any, _name: string)
	self._enemyEntityFactory = registry:Get("EnemyEntityFactory")
end

--[=[
	@within BehaviorTreeTickPolicy
	Returns the stored behavior tree when the entity is allowed to evaluate this frame.
	@param entity number -- Enemy entity id being evaluated.
	@param currentTime number -- Current timestamp used to enforce the tick interval.
	@return Result.Result<any> -- Behavior tree payload or an error when the entity cannot tick.
]=]
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
