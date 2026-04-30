--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BehaviorConfig = require(ReplicatedStorage.Contexts.Combat.Config.BehaviorConfig)
local AI = require(ReplicatedStorage.Utilities.AI)
local Result = require(ReplicatedStorage.Utilities.Result)
local Errors = require(script.Parent.Parent.Parent.Errors)
local Nodes = require(script.Parent.Parent.BehaviorSystem.Nodes)
local ExecutorDefinitions = require(script.Parent.Parent.BehaviorSystem.Executors)
local ActorAdapterHook = require(script.Parent.Parent.BehaviorSystem.Hooks.ActorAdapterHook)
local PerceptionHook = require(script.Parent.Parent.BehaviorSystem.Hooks.PerceptionHook)

local SwarmBehavior = require(script.Parent.Parent.BehaviorSystem.Behaviors.SwarmBehavior)
local TankBehavior = require(script.Parent.Parent.BehaviorSystem.Behaviors.TankBehavior)
local StructureBehavior = require(script.Parent.Parent.BehaviorSystem.Behaviors.StructureBehavior)

local Ok = Result.Ok
local Err = Result.Err

local EnemyBehaviorDefinitions = table.freeze({
	Swarm = SwarmBehavior,
	Tank = TankBehavior,
})

type TMergedRuntimeInputs = {
	Conditions: { [string]: (any?) -> any },
	Commands: { [string]: (any?) -> any },
	Executors: { [string]: any },
	Hooks: { any },
}

local CombatBehaviorRuntimeService = {}
CombatBehaviorRuntimeService.__index = CombatBehaviorRuntimeService

function CombatBehaviorRuntimeService.new()
	local self = setmetatable({}, CombatBehaviorRuntimeService)
	self._runtime = nil
	self._legacyRuntime = nil
	self._actorRegistryService = nil
	return self
end

function CombatBehaviorRuntimeService:Init(registry: any, _name: string)
	self._actorRegistryService = registry:Get("CombatActorRegistryService")
end

function CombatBehaviorRuntimeService:Start(registry: any, _name: string)
	local didResolveEnemyFactory, enemyEntityFactory = pcall(function()
		return registry:Get("EnemyEntityFactory")
	end)
	local didResolveStructureFactory, structureEntityFactory = pcall(function()
		return registry:Get("StructureEntityFactory")
	end)

	if didResolveEnemyFactory then
		self._enemyEntityFactory = enemyEntityFactory
	end
	if didResolveStructureFactory then
		self._structureEntityFactory = structureEntityFactory
	end

	if self._enemyEntityFactory ~= nil and self._structureEntityFactory ~= nil then
		self:_RegisterLegacyActorAdapters()
	end
end

function CombatBehaviorRuntimeService:StartRuntime(): Result.Result<boolean>
	if self._actorRegistryService:IsRuntimeStarted() then
		return Err("RuntimeAlreadyStarted", Errors.RUNTIME_ALREADY_STARTED)
	end

	if not self._actorRegistryService:HasActorTypes() then
		return Err("RuntimeStartFailed", Errors.RUNTIME_START_FAILED, {
			Reason = "NoActorTypesRegistered",
		})
	end

	local didBuild, buildResult = pcall(function()
		local mergedInputs = self:_BuildRuntimeInputs()
		local runtime = AI.CreateRuntime({
			Conditions = mergedInputs.Conditions,
			Commands = mergedInputs.Commands,
			Hooks = mergedInputs.Hooks,
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

		runtime:RegisterActions(mergedInputs.Executors)
		for _, actorTypePayload in ipairs(self._actorRegistryService:GetActorTypePayloads()) do
			runtime:RegisterActorType(actorTypePayload.ActorType, self:_CreateRegistryAdapter(actorTypePayload.ActorType))
		end

		return runtime
	end)

	if not didBuild then
		return Err("RuntimeStartFailed", Errors.RUNTIME_START_FAILED, {
			CauseMessage = buildResult,
		})
	end

	self._runtime = buildResult
	self._actorRegistryService:SetRuntimeStarted(true)

	return Ok(true)
end

function CombatBehaviorRuntimeService:StopRuntime(): Result.Result<boolean>
	if not self._actorRegistryService:IsRuntimeStarted() then
		return Ok(false)
	end

	self._runtime = nil
	self._actorRegistryService:SetRuntimeStarted(false)

	return Ok(true)
end

function CombatBehaviorRuntimeService:BuildTree(definition: any): Result.Result<any>
	if self._runtime == nil then
		return Err("RuntimeNotStarted", Errors.RUNTIME_NOT_STARTED)
	end

	local didBuild, tree = pcall(function()
		return self._runtime:BuildTree(definition)
	end)

	if not didBuild then
		return Err("RuntimeStartFailed", Errors.RUNTIME_START_FAILED, {
			CauseMessage = tree,
		})
	end

	return Ok(tree)
end

function CombatBehaviorRuntimeService:RunFrame(frameContext: any): any
	local runtime = self._runtime or self._legacyRuntime
	if runtime == nil then
		return {
			EntityResults = {},
			Defects = {},
		}
	end

	return runtime:RunFrame(frameContext)
end

function CombatBehaviorRuntimeService:CancelActorAction(actorType: string, runtimeId: number, frameContext: any): any
	local runtime = self._runtime or self._legacyRuntime
	if runtime == nil then
		return nil
	end

	self._actorRegistryService:CancelActor(runtimeId)
	return runtime:CancelActorAction(actorType, runtimeId, frameContext)
end

function CombatBehaviorRuntimeService:HandleActorDeath(actorType: string, runtimeId: number, frameContext: any): any
	local runtime = self._runtime or self._legacyRuntime
	if runtime == nil then
		return nil
	end

	return runtime:HandleActorDeath(actorType, runtimeId, frameContext)
end

function CombatBehaviorRuntimeService:GetExecutor(actionId: string)
	local runtime = self._runtime or self._legacyRuntime
	if runtime == nil then
		return nil
	end

	return runtime:GetExecutor(actionId)
end

function CombatBehaviorRuntimeService:BuildEnemyBehaviorTree(roleName: string): (any, number)
	self:_EnsureLegacyRuntime()
	local resolvedRole = if EnemyBehaviorDefinitions[roleName] ~= nil then roleName else "Swarm"
	local definition = EnemyBehaviorDefinitions[resolvedRole]
	local defaults = BehaviorConfig.DEFAULTS_BY_ROLE[resolvedRole] or BehaviorConfig.DEFAULT

	return self._legacyRuntime:BuildTree(definition), defaults.TickInterval
end

function CombatBehaviorRuntimeService:BuildStructureBehaviorTree(): (any, number)
	self:_EnsureLegacyRuntime()
	return self._legacyRuntime:BuildTree(StructureBehavior), BehaviorConfig.DEFAULT.TickInterval
end

function CombatBehaviorRuntimeService:CancelActorActions(actorType: string, entities: { number }, frameContext: any): any
	self:_EnsureLegacyRuntime()
	return self._legacyRuntime:CancelActorActions(actorType, entities, frameContext)
end

function CombatBehaviorRuntimeService:HandleActorDeaths(actorType: string, entities: { number }, frameContext: any): any
	self:_EnsureLegacyRuntime()
	return self._legacyRuntime:HandleActorDeaths(actorType, entities, frameContext)
end

function CombatBehaviorRuntimeService:_BuildRuntimeInputs(): TMergedRuntimeInputs
	local mergedInputs: TMergedRuntimeInputs = {
		Conditions = {},
		Commands = {},
		Executors = {},
		Hooks = {
			ActorAdapterHook,
		},
	}

	for _, actorTypePayload in ipairs(self._actorRegistryService:GetActorTypePayloads()) do
		self:_MergeNamedRegistry(mergedInputs.Conditions, actorTypePayload.Conditions, actorTypePayload.ActorType, "Condition")
		self:_MergeNamedRegistry(mergedInputs.Commands, actorTypePayload.Commands, actorTypePayload.ActorType, "Command")
		self:_MergeNamedRegistry(mergedInputs.Executors, actorTypePayload.Executors, actorTypePayload.ActorType, "Executor")
		self:_AppendHooks(mergedInputs.Hooks, actorTypePayload.Hooks)
	end

	return mergedInputs
end

function CombatBehaviorRuntimeService:_MergeNamedRegistry(
	target: { [string]: any },
	source: { [string]: any },
	_actorType: string,
	registryLabel: string
)
	for key, value in pairs(source) do
		assert(
			target[key] == nil,
			string.format("Combat %s '%s' is registered more than once; namespace actor actions by context", registryLabel, key)
		)
		target[key] = value
	end
end

function CombatBehaviorRuntimeService:_AppendHooks(target: { any }, hooks: { any }?)
	if hooks == nil then
		return
	end

	for _, hook in ipairs(hooks) do
		table.insert(target, hook)
	end
end

function CombatBehaviorRuntimeService:_EnsureLegacyRuntime()
	if self._legacyRuntime ~= nil then
		return
	end

	self._legacyRuntime = AI.CreateRuntime({
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
	self._legacyRuntime:RegisterActions(ExecutorDefinitions)
end

function CombatBehaviorRuntimeService:_RegisterLegacyActorAdapters()
	self:_EnsureLegacyRuntime()
	self._legacyRuntime:RegisterActorType(
		"Enemy",
		self:_CreateFactoryAdapter("Enemy", self._enemyEntityFactory, "QueryAliveEntities")
	)
	self._legacyRuntime:RegisterActorType(
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

function CombatBehaviorRuntimeService:_CreateRegistryAdapter(actorType: string): any
	return AI.CreateAdapter({
		ActorLabel = actorType,
		QueryActiveEntities = function(_frameContext: any): { number }
			return self._actorRegistryService:QueryActiveRuntimeIds(actorType)
		end,
		GetBehaviorTree = function(runtimeId: number): any?
			return self._actorRegistryService:GetBehaviorTree(runtimeId)
		end,
		GetActionState = function(runtimeId: number): any?
			return self._actorRegistryService:GetActionState(runtimeId)
		end,
		SetActionState = function(runtimeId: number, actionState: any)
			self._actorRegistryService:SetActionState(runtimeId, actionState)
		end,
		ClearActionState = function(runtimeId: number)
			self._actorRegistryService:ClearActionState(runtimeId)
		end,
		SetPendingAction = function(runtimeId: number, actionId: string, actionData: any?)
			self._actorRegistryService:SetPendingAction(runtimeId, actionId, actionData)
		end,
		UpdateLastTickTime = function(runtimeId: number, currentTime: number)
			self._actorRegistryService:UpdateLastTickTime(runtimeId, currentTime)
		end,
		ShouldEvaluate = function(runtimeId: number, currentTime: number): boolean
			return self._actorRegistryService:ShouldEvaluate(runtimeId, currentTime)
		end,
	})
end

return CombatBehaviorRuntimeService
