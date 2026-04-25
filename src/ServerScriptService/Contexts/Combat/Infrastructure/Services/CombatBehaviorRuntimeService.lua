--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BehaviorConfig = require(ReplicatedStorage.Contexts.Combat.Config.BehaviorConfig)
local BehaviorSystem = require(ReplicatedStorage.Utilities.BehaviorSystem)
local Nodes = require(script.Parent.Nodes)

local GoalAdvanceExecutor = require(script.Parent.Executors.GoalAdvanceExecutor)
local IdleExecutor = require(script.Parent.Executors.IdleExecutor)
local EnemyAttackStructureExecutor = require(script.Parent.Executors.EnemyAttackStructureExecutor)
local StructureAttackExecutor = require(script.Parent.Executors.StructureAttackExecutor)

local EnemyBehaviorDefinitions = table.freeze({
	swarm = table.freeze({
		Priority = {
			{
				Sequence = {
					"HasStructureTargetInRange",
					"AttackStructure",
				},
			},
			{
				Sequence = {
					"HasGoalTarget",
					"GoalAdvance",
				},
			},
			"Idle",
		},
	}),
	tank = table.freeze({
		Priority = {
			{
				Sequence = {
					"HasStructureTargetInRange",
					"AttackStructure",
				},
			},
			{
				Sequence = {
					"HasGoalTarget",
					"GoalAdvance",
				},
			},
			"Idle",
		},
	}),
})

local StructureBehaviorDefinition = table.freeze({
	Priority = {
		{
			Sequence = {
				"HasEnemyTargetInRange",
				"StructureAttack",
			},
		},
		"Idle",
	},
})

--[=[
	@class CombatBehaviorRuntimeService
	Owns Combat's shared BehaviorSystem runtime, behavior definitions, and executor registration.
	@server
]=]
local CombatBehaviorRuntimeService = {}
CombatBehaviorRuntimeService.__index = CombatBehaviorRuntimeService

--[=[
	@within CombatBehaviorRuntimeService
	Creates the shared runtime and registers Combat action executors once.
	@return CombatBehaviorRuntimeService -- Service instance that builds trees and dispatches actions.
]=]
function CombatBehaviorRuntimeService.new()
	local self = setmetatable({}, CombatBehaviorRuntimeService)
	self._runtime = BehaviorSystem.new({
		Conditions = Nodes.Conditions,
		Commands = Nodes.Commands,
	})

	self._runtime:RegisterActions({
		GoalAdvance = {
			ActionId = "GoalAdvance",
			CreateExecutor = GoalAdvanceExecutor.new,
		},
		Idle = {
			ActionId = "Idle",
			CreateExecutor = IdleExecutor.new,
		},
		AttackStructure = {
			ActionId = "AttackStructure",
			CreateExecutor = EnemyAttackStructureExecutor.new,
		},
		StructureAttack = {
			ActionId = "StructureAttack",
			CreateExecutor = StructureAttackExecutor.new,
		},
	})

	return self
end

--[=[
	@within CombatBehaviorRuntimeService
	No-op initialization hook kept for registry symmetry.
	@param _registry any -- Registry instance supplied by the context bootstrap.
	@param _name string -- Registry key used to register the service.
]=]
function CombatBehaviorRuntimeService:Init(_registry: any, _name: string)
end

local function _resolveEnemyRole(roleName: string): string
	local normalizedRole = string.lower(roleName)
	if EnemyBehaviorDefinitions[normalizedRole] ~= nil then
		return normalizedRole
	end

	return "swarm"
end

--[=[
	@within CombatBehaviorRuntimeService
	Builds a role-specific enemy behavior tree and returns the matching tick interval.
	@param roleName string -- Enemy role name used to select the symbolic behavior definition.
	@return any -- Compiled behavior tree instance.
	@return number -- Tick interval configured for the selected role.
]=]
function CombatBehaviorRuntimeService:BuildEnemyBehaviorTree(roleName: string): (any, number)
	local resolvedRole = _resolveEnemyRole(roleName)
	local definition = EnemyBehaviorDefinitions[resolvedRole]
	local defaults = BehaviorConfig.DEFAULTS_BY_ROLE[resolvedRole] or BehaviorConfig.DEFAULT

	return self._runtime:BuildTree(definition), defaults.TickInterval
end

--[=[
	@within CombatBehaviorRuntimeService
	Builds the shared structure behavior tree and returns its tick interval.
	@return any -- Compiled behavior tree instance.
	@return number -- Tick interval used for structure AI.
]=]
function CombatBehaviorRuntimeService:BuildStructureBehaviorTree(): (any, number)
	return self._runtime:BuildTree(StructureBehaviorDefinition), BehaviorConfig.DEFAULT.TickInterval
end

--[=[
	@within CombatBehaviorRuntimeService
	Returns the stored behavior tree when the entity is allowed to evaluate this frame.
	@param factory any -- Entity factory that owns the behavior and action components.
	@param entity number -- Entity id being evaluated.
	@param currentTime number -- Shared timestamp for the current combat tick.
	@return any? -- Behavior tree component payload or `nil` when the entity should skip evaluation.
]=]
function CombatBehaviorRuntimeService:GetReadyBehaviorTree(factory: any, entity: number, currentTime: number): any?
	local actionState = factory:GetCombatAction(entity)
	if actionState and actionState.ActionState == "Committed" then
		return nil
	end

	local behaviorTree = factory:GetBehaviorTree(entity)
	if behaviorTree == nil then
		return nil
	end

	if currentTime - behaviorTree.LastTickTime < behaviorTree.TickInterval then
		return nil
	end

	return behaviorTree
end

function CombatBehaviorRuntimeService:StartPendingAction(entity: number, actionState: any, runtimeContext: any)
	return self._runtime:StartPendingAction(entity, actionState, runtimeContext)
end

function CombatBehaviorRuntimeService:CommitStartedAction(actionState: any, startResult: any, startedAt: number)
	return self._runtime:CommitStartedAction(actionState, startResult, startedAt)
end

function CombatBehaviorRuntimeService:TickCurrentAction(entity: number, actionState: any, runtimeContext: any)
	return self._runtime:TickCurrentAction(entity, actionState, runtimeContext)
end

function CombatBehaviorRuntimeService:ResolveFinishedAction(actionState: any, tickResult: any, finishedAt: number)
	return self._runtime:ResolveFinishedAction(actionState, tickResult, finishedAt)
end

function CombatBehaviorRuntimeService:CancelCurrentAction(entity: number, actionState: any, runtimeContext: any)
	return self._runtime:CancelCurrentAction(entity, actionState, runtimeContext)
end

function CombatBehaviorRuntimeService:GetExecutor(actionId: string)
	return self._runtime:GetExecutor(actionId)
end

return CombatBehaviorRuntimeService
