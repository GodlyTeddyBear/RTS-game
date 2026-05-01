--!strict

--[=[
    @class EnemyCombatAdapterService
    Bridges enemy entities into the combat runtime and wires enemy-specific targeting, movement, and damage adapters.
    @server
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AI = require(ReplicatedStorage.Utilities.AI)
local Result = require(ReplicatedStorage.Utilities.Result)
local EnemyConfig = require(ReplicatedStorage.Contexts.Enemy.Config.EnemyConfig)
local EnemyTypes = require(ReplicatedStorage.Contexts.Enemy.Types.EnemyTypes)
local Nodes = require(script.Parent.Parent.BehaviorSystem.Nodes)
local Executors = require(script.Parent.Parent.BehaviorSystem.Executors)
local EnemyRuntimeProfiles = require(script.Parent.Parent.Runtime.Profiles.EnemyRuntimeProfiles)
local EnemyFactsResolverFactory = require(script.Parent.Parent.Runtime.Resolvers.EnemyFactsResolverFactory)
local EnemyFactoryProxyResolverFactory = require(script.Parent.Parent.Runtime.Resolvers.EnemyFactoryProxyResolverFactory)
local EnemyGoalAssignmentResolverFactory = require(script.Parent.Parent.Runtime.Resolvers.EnemyGoalAssignmentResolverFactory)
local EnemyHitTargetResolverFactory = require(script.Parent.Parent.Runtime.Resolvers.EnemyHitTargetResolverFactory)
local EnemyHitboxProxyResolverFactory = require(script.Parent.Parent.Runtime.Resolvers.EnemyHitboxProxyResolverFactory)
local EnemyMeleeResolverFactory = require(script.Parent.Parent.Runtime.Resolvers.EnemyMeleeResolverFactory)
local EnemyMovementProxyResolverFactory = require(script.Parent.Parent.Runtime.Resolvers.EnemyMovementProxyResolverFactory)
local EnemyPerceptionResolverFactory = require(script.Parent.Parent.Runtime.Resolvers.EnemyPerceptionResolverFactory)
local EnemyTargetingResolverFactory = require(script.Parent.Parent.Runtime.Resolvers.EnemyTargetingResolverFactory)

type EnemyRole = EnemyTypes.EnemyRole
type EnemyRoleConfig = EnemyTypes.EnemyRoleConfig

local EnemySemanticRequirements = table.freeze({
	FactsDependOnPolling = true,
	AttributesDependOnProjection = true,
})

local EnemyRuntimeBinding = table.freeze({
	ServiceField = "_syncService",
	PollPhase = "EnemySync",
	SyncPhase = "EnemySync",
})

local EnemyCombatAdapterService = {}
EnemyCombatAdapterService.__index = EnemyCombatAdapterService

-- ── Public ────────────────────────────────────────────────────────────────────

-- Creates a new enemy combat adapter service with deferred combat-service wiring.
--[=[
    @within EnemyCombatAdapterService
    Creates a new enemy combat adapter service.
    @return EnemyCombatAdapterService -- Service instance used to register enemy combat actors.
]=]
function EnemyCombatAdapterService.new()
	local self = setmetatable({}, EnemyCombatAdapterService)
	self._configuredCombatServices = false
	self._runtimeOwner = nil
	return self
end

-- Resolves the entity factories needed to build enemy actor adapters.
--[=[
    @within EnemyCombatAdapterService
    Resolves the enemy context dependencies used by the adapter service.
    @param registry any -- Registry instance supplied by the context bootstrap.
    @param _name string -- Registry key used to register the service.
]=]
function EnemyCombatAdapterService:Init(registry: any, _name: string)
	self._entityFactory = registry:Get("EnemyEntityFactory")
	self._instanceFactory = registry:Get("EnemyInstanceFactory")
end

-- Caches cross-context references and wires combat services once.
--[=[
    @within EnemyCombatAdapterService
    Resolves the combat, structure, and base dependencies used by the adapter service.
    @param registry any -- Registry instance supplied by the context bootstrap.
    @param _name string -- Registry key used to register the service.
]=]
function EnemyCombatAdapterService:Start(registry: any, _name: string)
	self._combatContext = registry:Get("CombatContext")
	self._structureContext = registry:Get("StructureContext")
	self._baseContext = registry:Get("BaseContext")
	self._structureEntityFactory = self._structureContext:GetEntityFactory().value
	self._baseEntityFactory = self._baseContext:GetEntityFactory().value
	self._combatServices = self._combatContext:GetCombatRuntimeServices().value
	self._targetingResolver = EnemyTargetingResolverFactory.Create({
		BaseEntityFactory = self._baseEntityFactory,
		StructureEntityFactory = self._structureEntityFactory,
	})
	self._factsResolver = EnemyFactsResolverFactory.Create({
		EnemyEntityFactory = self._entityFactory,
		TargetingResolver = self._targetingResolver,
	})
	self._perceptionResolver = EnemyPerceptionResolverFactory.Create({
		TargetingResolver = self._targetingResolver,
	})
	self._movementProxyResolver = EnemyMovementProxyResolverFactory.Create({
		MovementService = self._combatServices.MovementService,
	})
	self._enemyFactoryProxyResolver = EnemyFactoryProxyResolverFactory.Create({
		EnemyEntityFactory = self._entityFactory,
	})
	self._hitboxProxyResolver = EnemyHitboxProxyResolverFactory.Create({
		EnemyEntityFactory = self._entityFactory,
		HitboxService = self._combatServices.HitboxService,
	})
	self._goalAssignmentResolver = EnemyGoalAssignmentResolverFactory.Create({
		BaseContext = self._baseContext,
		EnemyEntityFactory = self._entityFactory,
	})
	self:_ConfigureCombatServices()
end

-- Registers the enemy actor type so the combat runtime can instantiate enemy behavior trees.
--[=[
    @within EnemyCombatAdapterService
    Registers the enemy actor type with the combat runtime.
    @return Result.Result<boolean> -- Whether the actor type registration succeeded.
]=]
function EnemyCombatAdapterService:RegisterActorType(): Result.Result<boolean>
	return Result.Catch(function()
		AI.ValidateSemanticContract("Enemy", EnemySemanticRequirements, EnemyRuntimeBinding, {
			RuntimeOwner = self._runtimeOwner,
		})

		return self._combatContext:RegisterActorType({
			ActorType = "Enemy",
			Conditions = Nodes.Conditions,
			Commands = Nodes.Commands,
			Executors = Executors,
			SemanticRequirements = EnemySemanticRequirements,
			RuntimeBinding = EnemyRuntimeBinding,
			RuntimeOwner = self._runtimeOwner,
		})
	end, "Enemy:RegisterActorType")
end

-- Registers one enemy entity as a runtime actor and builds its per-tick adapter hooks.
--[=[
    @within EnemyCombatAdapterService
    Registers one enemy entity with the combat runtime.
    @param entity number -- Enemy entity id to register.
    @return Result.Result<string> -- Actor handle for the registered enemy.
]=]
function EnemyCombatAdapterService:RegisterActor(entity: number): Result.Result<string>
	-- Resolve the enemy identity and behavior profile before the runtime sees the actor.
	local identity = self._entityFactory:GetIdentity(entity)
	local role = self._entityFactory:GetRole(entity)
	local roleName = if role ~= nil and role.Role ~= nil then role.Role else "Swarm"
	local roleConfig = EnemyConfig.Roles[roleName] :: EnemyRoleConfig?
	assert(roleConfig ~= nil, ("EnemyCombatAdapterService: missing config for role '%s'"):format(tostring(roleName)))
	local runtimeProfile = EnemyRuntimeProfiles.GetByVariant(roleConfig.RuntimeProfileId)
	local actorHandle = self:_BuildActorHandle(entity)

	-- Seed the goal position and lock-on state before the actor begins ticking.
	self._goalAssignmentResolver.AssignGoalPosition(entity, actorHandle, roleName)
	self._combatServices.LockOnService:AttachConstraint(entity)
	self._entityFactory:SetBehaviorConfig(entity, {
		TickInterval = runtimeProfile.TickInterval,
	})

	-- Hand the combat runtime a thin adapter that delegates back into the enemy context.
	return self._combatContext:RegisterCombatActor({
		ActorType = "Enemy",
		ActorHandle = actorHandle,
		BehaviorDefinition = runtimeProfile.BehaviorDefinition,
		TickInterval = runtimeProfile.TickInterval,
		Adapter = {
			IsActive = function(): boolean
				return self._entityFactory:IsAlive(entity)
			end,
			GetActorLabel = function(): string?
				return if identity ~= nil then identity.EnemyId else actorHandle
			end,
			BuildFacts = function(currentTime: number): { [string]: any }
				return self:_BuildFacts(entity, currentTime)
			end,
			BuildServices = function(currentTime: number): { [string]: any }
				return self:_BuildServices(entity, currentTime)
			end,
			OnCancel = function()
				self._combatServices.MovementService:StopMovement(entity)
			end,
			OnRemoved = function()
				self._combatServices.MovementService:StopMovement(entity)
				self._combatServices.LockOnService:DetachConstraint(entity)
			end,
			OnActionStateChanged = function(_actionState: any)
				self._entityFactory:MarkDirty(entity)
			end,
			OnActionResult = function(actionResult: any)
				self:_HandleActionResult(entity, actionResult)
			end,
		},
	})
end

-- Unregisters one enemy actor handle when its entity leaves the runtime.
--[=[
    @within EnemyCombatAdapterService
    Unregisters one enemy actor from the combat runtime.
    @param entity number -- Enemy entity id to unregister.
    @return Result.Result<boolean> -- Whether the actor was removed successfully.
]=]
function EnemyCombatAdapterService:UnregisterActor(entity: number): Result.Result<boolean>
	return self._combatContext:UnregisterCombatActor(self:_BuildActorHandle(entity))
end

-- Returns the stable combat actor handle for one enemy entity.
--[=[
    @within EnemyCombatAdapterService
    Returns the combat actor handle for one enemy entity.
    @param entity number -- Enemy entity id to resolve.
    @return string -- Stable actor handle used by the combat runtime.
]=]
function EnemyCombatAdapterService:GetActorHandle(entity: number): string
	return self:_BuildActorHandle(entity)
end

-- Stores the context that owns this adapter so callbacks can resolve back into it.
--[=[
    @within EnemyCombatAdapterService
    Stores the runtime owner that owns this adapter service.
    @param runtimeOwner any -- Owning context or runtime object.
]=]
function EnemyCombatAdapterService:ConfigureRuntimeOwner(runtimeOwner: any)
	self._runtimeOwner = runtimeOwner
end

-- ── Private ───────────────────────────────────────────────────────────────────

-- Configures shared combat services once so all enemy actors reuse the same adapters.
function EnemyCombatAdapterService:_ConfigureCombatServices()
	if self._configuredCombatServices then
		return
	end

	-- Install shared enemy target resolution before any combat tick asks for hit validation.
	local hitTargetResolver = EnemyHitTargetResolverFactory.Create({
		BaseEntityFactory = self._baseEntityFactory,
		StructureEntityFactory = self._structureEntityFactory,
	})

	self._combatServices.HitboxService:RegisterTargetResolver(function(hitPart: BasePart): any?
		return hitTargetResolver.ResolveHitTarget(hitPart)
	end)
	self._combatServices.MovementService:ConfigureEnemyEntityFactory(self._entityFactory)
	self._combatServices.LockOnService:ConfigureFactories(
		self._entityFactory,
		self._structureEntityFactory,
		self._baseEntityFactory
	)
	self._combatServices.CombatHitResolutionService:ConfigureEnemyMeleeResolver(
		EnemyMeleeResolverFactory.Create({
			BaseContext = self._baseContext,
			BaseEntityFactory = self._baseEntityFactory,
			StructureContext = self._structureContext,
			StructureEntityFactory = self._structureEntityFactory,
		})
	)

	self._configuredCombatServices = true
end

-- Builds the stable combat handle, preferring the enemy's configured id when present.
function EnemyCombatAdapterService:_BuildActorHandle(entity: number): string
	local identity = self._entityFactory:GetIdentity(entity)
	if identity ~= nil and type(identity.EnemyId) == "string" then
		return "Enemy:" .. identity.EnemyId
	end
	return "Enemy:" .. tostring(entity)
end

-- Builds the fact snapshot consumed by enemy behavior nodes on each combat tick.
function EnemyCombatAdapterService:_BuildFacts(entity: number, _currentTime: number): { [string]: any }
	return self._factsResolver.BuildFacts(entity, _currentTime)
end

-- Builds the service map exposed to enemy behavior executors for the current tick.
function EnemyCombatAdapterService:_BuildServices(entity: number, currentTime: number): { [string]: any }
	return {
		EnemyEntityFactory = self._enemyFactoryProxyResolver.CreateProxy(entity),
		StructureEntityFactory = self._structureEntityFactory,
		BaseEntityFactory = self._baseEntityFactory,
		CombatPerceptionService = self._perceptionResolver.CreateProxy(),
		EnemyContext = nil,
		StructureContext = self._structureContext,
		BaseContext = self._baseContext,
		CurrentTime = currentTime,
		HitboxService = self._hitboxProxyResolver.CreateProxy(entity),
		MovementService = self._movementProxyResolver.CreateProxy(entity),
		CombatHitResolutionService = self._combatServices.CombatHitResolutionService,
	}
end

-- Refreshes lock-on state after the combat runtime reports an action result.
function EnemyCombatAdapterService:_HandleActionResult(entity: number, _actionResult: any)
	self._combatServices.LockOnService:UpdateAll({ entity })
end

return EnemyCombatAdapterService
