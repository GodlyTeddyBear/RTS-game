--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BehaviorConfig = require(ReplicatedStorage.Contexts.Combat.Config.BehaviorConfig)
local AI = require(ReplicatedStorage.Utilities.AI)
local Result = require(ReplicatedStorage.Utilities.Result)
local Nodes = require(script.Parent.Parent.BehaviorSystem.Nodes)
local ExecutorDefinitions = require(script.Parent.Parent.BehaviorSystem.Executors)
local PerceptionHook = require(script.Parent.Parent.BehaviorSystem.Hooks.PerceptionHook)

local SwarmBehavior = require(script.Parent.Parent.BehaviorSystem.Behaviors.SwarmBehavior)
local TankBehavior = require(script.Parent.Parent.BehaviorSystem.Behaviors.TankBehavior)
local StructureBehavior = require(script.Parent.Parent.BehaviorSystem.Behaviors.StructureBehavior)

local EnemyBehaviorDefinitions = table.freeze({
	Swarm = SwarmBehavior,
	Tank = TankBehavior,
})

--[=[
	@class CombatBehaviorRuntimeService
	Owns Combat's shared AI runtime, behavior definitions, actor adapters, and executor registration.
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
	self._runtime = AI.CreateRuntime({
		Conditions = Nodes.Conditions,
		Commands = Nodes.Commands,
		Hooks = {
			PerceptionHook,
		},
		ErrorSink = function(payload: any)
			Result.MentionError("Combat:BehaviorRuntime", "AI runtime defect", {
				Stage = payload.Stage,
				ActorType = payload.ActorType,
				ActorLabel = payload.ActorLabel,
				Entity = payload.Entity,
				CauseType = payload.ErrorType,
				CauseMessage = payload.ErrorMessage,
				Details = payload.Details,
			}, payload.ErrorType)
		end,
	})

	self._runtime:RegisterActions(ExecutorDefinitions)

	return self
end

--[=[
	@within CombatBehaviorRuntimeService
	No-op initialization hook kept for registry symmetry.
	@param _registry any -- Registry instance supplied by the context bootstrap.
	@param _name string -- Registry key used to register the service.
]=]
function CombatBehaviorRuntimeService:Init(_registry: any, _name: string) end

function CombatBehaviorRuntimeService:Start(registry: any, _name: string)
	self._enemyEntityFactory = registry:Get("EnemyEntityFactory")
	self._structureEntityFactory = registry:Get("StructureEntityFactory")

	self:_RegisterActorAdapters()
end

local function _resolveEnemyRole(roleName: string): string
	if EnemyBehaviorDefinitions[roleName] ~= nil then
		return roleName
	end

	return "Swarm"
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
	return self._runtime:BuildTree(StructureBehavior), BehaviorConfig.DEFAULT.TickInterval
end

function CombatBehaviorRuntimeService:RunFrame(frameContext: any): any
	return self._runtime:RunFrame(frameContext)
end

function CombatBehaviorRuntimeService:CancelActorAction(actorType: string, entity: number, frameContext: any): any
	return self._runtime:CancelActorAction(actorType, entity, frameContext)
end

function CombatBehaviorRuntimeService:CancelActorActions(actorType: string, entities: { number }, frameContext: any): any
	return self._runtime:CancelActorActions(actorType, entities, frameContext)
end

function CombatBehaviorRuntimeService:HandleActorDeath(actorType: string, entity: number, frameContext: any): any
	return self._runtime:HandleActorDeath(actorType, entity, frameContext)
end

function CombatBehaviorRuntimeService:HandleActorDeaths(actorType: string, entities: { number }, frameContext: any): any
	return self._runtime:HandleActorDeaths(actorType, entities, frameContext)
end

function CombatBehaviorRuntimeService:GetExecutor(actionId: string)
	return self._runtime:GetExecutor(actionId)
end

function CombatBehaviorRuntimeService:_RegisterActorAdapters()
	self._runtime:RegisterActorType("Enemy", self:_CreateFactoryAdapter("Enemy", self._enemyEntityFactory, "QueryAliveEntities"))
	self._runtime:RegisterActorType(
		"Structure",
		self:_CreateFactoryAdapter("Structure", self._structureEntityFactory, "QueryActiveEntities")
	)
end

function CombatBehaviorRuntimeService:_CreateFactoryAdapter(
	actorLabel: string,
	factory: any,
	queryActiveEntitiesMethod: string
): any
	return AI.CreateFactoryAdapter({
		ActorLabel = actorLabel,
		Factory = factory,
		QueryActiveEntities = queryActiveEntitiesMethod,
		GetBehaviorTree = "GetBehaviorTree",
		GetActionState = "GetCombatAction",
		SetActionState = "SetCombatAction",
		ClearActionState = "ClearAction",
		SetPendingAction = "SetPendingAction",
		UpdateLastTickTime = "UpdateBTLastTickTime",
		ShouldEvaluate = function(factoryObject: any, entity: number, currentTime: number): boolean
			local actionState = factoryObject:GetCombatAction(entity)
			if actionState and actionState.ActionState == "Committed" then
				return false
			end

			local behaviorTree = factoryObject:GetBehaviorTree(entity)
			if behaviorTree == nil then
				return false
			end

			return currentTime - behaviorTree.LastTickTime >= behaviorTree.TickInterval
		end,
	})
end

return CombatBehaviorRuntimeService
