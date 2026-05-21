--!strict

--[=[
    @class StructureCombatAdapterService
    Bridges structure entities into the combat runtime and wires structure attacks to enemy targeting and damage.
    @server
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local AI = require(ServerStorage.Utilities.ContextUtilities.AI)
local Result = require(ReplicatedStorage.Utilities.Result)
local RuntimeFactCache = require(ServerStorage.Utilities.ContextUtilities.RuntimeFactCache)
local StructureConfig = require(ReplicatedStorage.Contexts.Structure.Config.StructureConfig)
local StructureTypes = require(ReplicatedStorage.Contexts.Structure.Types.StructureTypes)
local Nodes = require(script.Parent.Parent.BehaviorSystem.Nodes)
local StructureAttackExecutor = require(script.Parent.Parent.BehaviorSystem.Executors.StructureAttackExecutor)
local StructureStasisExecutor = require(script.Parent.Parent.BehaviorSystem.Executors.StructureStasisExecutor)
local StructureRuntimeProfiles = require(script.Parent.Parent.Runtime.Profiles.StructureRuntimeProfiles)
local StructureFactsResolverFactory = require(script.Parent.Parent.Runtime.Resolvers.StructureFactsResolverFactory)
local StructureFactoryProxyResolverFactory = require(script.Parent.Parent.Runtime.Resolvers.StructureFactoryProxyResolverFactory)
local StructureHitTargetResolverFactory = require(script.Parent.Parent.Runtime.Resolvers.StructureHitTargetResolverFactory)
local StructurePerceptionResolverFactory = require(script.Parent.Parent.Runtime.Resolvers.StructurePerceptionResolverFactory)
local StructureProjectileResolverFactory = require(script.Parent.Parent.Runtime.Resolvers.StructureProjectileResolverFactory)
local StructureProjectileProxyResolverFactory = require(script.Parent.Parent.Runtime.Resolvers.StructureProjectileProxyResolverFactory)
local StructureTargetingResolverFactory = require(script.Parent.Parent.Runtime.Resolvers.StructureTargetingResolverFactory)

type StructureType = StructureTypes.StructureType
type TStructureConfig = StructureTypes.TStructureConfig

local StructureCombatAdapterService = {}
StructureCombatAdapterService.__index = StructureCombatAdapterService

local StructureSemanticRequirements = table.freeze({
	FactsDependOnPolling = false,
	AttributesDependOnProjection = true,
})

local StructureRuntimeBinding = table.freeze({
	ServiceField = "_gameObjectSyncService",
	SyncPhase = "StructureSync",
})
local POSITION_INVALIDATION_EPSILON = 1e-4
local FACT_CACHE_REFRESH_INTERVAL_SECONDS = 0.2
local FACT_GROUP_CACHE_REFRESH_INTERVAL_SECONDS = 1
local CHEAP_FACT_GROUP_COMBAT_STATS = "CombatStats"
local CHEAP_FACT_GROUP_SPATIAL = "Spatial"

local function _CloneActionState(actionState: any): any
	if type(actionState) ~= "table" then
		return {
			CurrentActionId = nil,
			ActionState = "Idle",
			ActionData = nil,
			PendingActionId = nil,
			PendingActionData = nil,
			StartedAt = nil,
			FinishedAt = nil,
		}
	end

	return {
		CurrentActionId = actionState.CurrentActionId,
		ActionState = actionState.ActionState or "Idle",
		ActionData = actionState.ActionData,
		PendingActionId = actionState.PendingActionId,
		PendingActionData = actionState.PendingActionData,
		StartedAt = actionState.StartedAt,
		FinishedAt = actionState.FinishedAt,
	}
end

local function _HasPositionChanged(previousPosition: Vector3?, currentPosition: Vector3?): boolean
	if previousPosition == nil or currentPosition == nil then
		return previousPosition ~= currentPosition
	end

	return (currentPosition - previousPosition).Magnitude > POSITION_INVALIDATION_EPSILON
end

-- ── Public ────────────────────────────────────────────────────────────────────

-- Creates a new structure combat adapter service with deferred combat-service wiring.
--[=[
    @within StructureCombatAdapterService
    Creates a new structure combat adapter service.
    @return StructureCombatAdapterService -- Service instance used to register structure combat actors.
]=]
function StructureCombatAdapterService.new()
	local self = setmetatable({}, StructureCombatAdapterService)
	self._configuredCombatServices = false
	self._runtimeOwner = nil
	self._cachedFactsByEntity = {}
	self._cachedExecutorServicesByEntity = {}
	return self
end

-- Resolves the structure entity factory used to build actor adapters.
--[=[
    @within StructureCombatAdapterService
    Resolves the structure context dependencies used by the adapter service.
    @param registry any -- Registry instance supplied by the context bootstrap.
    @param _name string -- Registry key used to register the service.
]=]
function StructureCombatAdapterService:Init(registry: any, _name: string)
	self._entityFactory = registry:Get("StructureEntityFactory")
end

-- Caches combat and enemy dependencies before the first structure actor is registered.
--[=[
    @within StructureCombatAdapterService
    Resolves the combat and enemy dependencies used by the adapter service.
    @param registry any -- Registry instance supplied by the context bootstrap.
    @param _name string -- Registry key used to register the service.
]=]
function StructureCombatAdapterService:Start(registry: any, _name: string)
	self._combatContext = registry:Get("CombatContext")
	self._enemyContext = registry:Get("EnemyContext")
	self._enemyEntityFactory = self._enemyContext:GetEntityFactory().value
	self._enemyInstanceFactory = self._enemyContext:GetInstanceFactory().value
	self._instanceFactory = registry:Get("StructureInstanceFactory")
	self._combatServices = self._combatContext:GetCombatRuntimeServices().value
	self._targetingResolver = StructureTargetingResolverFactory.Create({
		EnemyEntityFactory = self._enemyEntityFactory,
		EnemyInstanceFactory = self._enemyInstanceFactory,
	})
	self._factsResolver = StructureFactsResolverFactory.Create({
		StructureEntityFactory = self._entityFactory,
		TargetingResolver = self._targetingResolver,
	})
	self._perceptionResolver = StructurePerceptionResolverFactory.Create({
		TargetingResolver = self._targetingResolver,
	})
	self._structureFactoryProxyResolver = StructureFactoryProxyResolverFactory.Create({
		StructureEntityFactory = self._entityFactory,
	})
	self._projectileProxyResolver = StructureProjectileProxyResolverFactory.Create({
		ProjectileService = self._combatServices.ProjectileService,
	})
	self:_ConfigureCombatServices()
end

-- Registers the structure actor type so the combat runtime can instantiate structure behavior trees.
--[=[
    @within StructureCombatAdapterService
    Registers the structure actor type with the combat runtime.
    @return Result.Result<boolean> -- Whether the actor type registration succeeded.
]=]
function StructureCombatAdapterService:RegisterActorType(): Result.Result<boolean>
	return Result.Catch(function()
		AI.ValidateSemanticContract("Structure", StructureSemanticRequirements, StructureRuntimeBinding, {
			RuntimeOwner = self._runtimeOwner,
		})

		return self._combatContext:RegisterActorType({
			ActorType = "Structure",
			Conditions = Nodes.Conditions,
			Commands = Nodes.Commands,
			Executors = {
				["Structure.Attack"] = table.freeze({
					ActionId = "Structure.Attack",
					CreateExecutor = StructureAttackExecutor.new,
				}),
				["Structure.Stasis"] = table.freeze({
					ActionId = "Structure.Stasis",
					CreateExecutor = StructureStasisExecutor.new,
				}),
			},
			SemanticRequirements = StructureSemanticRequirements,
			RuntimeBinding = StructureRuntimeBinding,
			RuntimeOwner = self._runtimeOwner,
		})
	end, "Structure:RegisterActorType")
end

-- Registers one structure entity as a runtime actor and builds its per-tick adapter hooks.
--[=[
    @within StructureCombatAdapterService
    Registers one structure entity with the combat runtime.
    @param entity number -- Structure entity id to register.
    @return Result.Result<string> -- Actor handle for the registered structure.
]=]
function StructureCombatAdapterService:RegisterActor(entity: number): Result.Result<string>
	local identity = self._entityFactory:GetIdentity(entity)
	assert(identity ~= nil, "StructureCombatAdapterService: missing identity for structure actor")

	local structureConfig = StructureConfig.STRUCTURES[identity.StructureType] :: TStructureConfig?
	assert(
		structureConfig ~= nil,
		("StructureCombatAdapterService: missing config for structure type '%s'"):format(tostring(identity.StructureType))
	)

	if structureConfig.RuntimeProfileId ~= "Attack" and structureConfig.RuntimeProfileId ~= "Stasis" then
		return Result.Ok(self:_BuildActorHandle(entity))
	end

	local runtimeProfile = StructureRuntimeProfiles.GetByVariant(structureConfig.RuntimeProfileId)
	local actorHandle = self:_BuildActorHandle(entity)
	self._entityFactory:SetBehaviorConfig(entity, {
		TickInterval = runtimeProfile.TickInterval,
	})

	return self._combatContext:RegisterCombatActor({
		ActorType = "Structure",
		ActorHandle = actorHandle,
		BehaviorDefinition = runtimeProfile.BehaviorDefinition,
		TickInterval = runtimeProfile.TickInterval,
		Adapter = {
			IsActive = function(): boolean
				return self._entityFactory:IsActive(entity)
			end,
			GetActorLabel = function(): string?
				return self:_BuildActorHandle(entity)
			end,
			BuildFacts = function(currentTime: number): { [string]: any }
				return self:_BuildFacts(entity, currentTime)
			end,
			BuildServices = function(currentTime: number, tickId: number?, frameContext: any?): { [string]: any }
				return self:_BuildServices(entity, currentTime, tickId, frameContext)
			end,
			OnRemoved = function()
				self:_ClearCachedFacts(entity)
				self:_ClearCachedExecutorServices(entity)
				self._combatServices.StatusService:RemoveAuraSource(actorHandle)
			end,
			OnActionStateChanged = function(actionState: any)
				self._entityFactory:SetCombatAction(entity, _CloneActionState(actionState))
			end,
		},
	})
end

-- Unregisters one structure actor when its entity leaves the runtime.
--[=[
    @within StructureCombatAdapterService
    Unregisters one structure actor from the combat runtime.
    @param entity number -- Structure entity id to unregister.
    @return Result.Result<boolean> -- Whether the actor was removed successfully.
]=]
function StructureCombatAdapterService:UnregisterActor(entity: number): Result.Result<boolean>
	if not self:ShouldRegisterActor(entity) then
		return Result.Ok(false)
	end

	self:_ClearCachedFacts(entity)
	self:_ClearCachedExecutorServices(entity)
	return self._combatContext:UnregisterCombatActor(self:_BuildActorHandle(entity))
end

-- Returns the stable combat actor handle for one structure entity.
--[=[
    @within StructureCombatAdapterService
    Returns the combat actor handle for one structure entity.
    @param entity number -- Structure entity id to resolve.
    @return string -- Stable actor handle used by the combat runtime.
]=]
function StructureCombatAdapterService:GetActorHandle(entity: number): string
	return self:_BuildActorHandle(entity)
end

-- Stores the context that owns this adapter so callbacks can resolve back into it.
--[=[
    @within StructureCombatAdapterService
    Stores the runtime owner that owns this adapter service.
    @param runtimeOwner any -- Owning context or runtime object.
]=]
function StructureCombatAdapterService:ConfigureRuntimeOwner(runtimeOwner: any)
	self._runtimeOwner = runtimeOwner
end

function StructureCombatAdapterService:ShouldRegisterActor(entity: number): boolean
	local identity = self._entityFactory:GetIdentity(entity)
	if identity == nil then
		return false
	end

	local structureConfig = StructureConfig.STRUCTURES[identity.StructureType] :: TStructureConfig?
	if structureConfig == nil then
		return false
	end

	return structureConfig.RuntimeProfileId == "Attack" or structureConfig.RuntimeProfileId == "Stasis"
end

-- ── Private ───────────────────────────────────────────────────────────────────

-- Configures shared combat services once so all structure actors reuse the same adapters.
function StructureCombatAdapterService:_ConfigureCombatServices()
	if self._configuredCombatServices then
		return
	end

	-- Install shared hit validation before any structure actor asks for melee or projectile checks.
	local hitTargetResolver = StructureHitTargetResolverFactory.Create({
		EnemyInstanceFactory = self._enemyInstanceFactory,
	})

	self._combatServices.HitboxService:RegisterTargetResolver(function(hitPart: BasePart): any?
		return hitTargetResolver.ResolveHitTarget(hitPart)
	end)
	self._combatServices.HitboxService:RegisterWhitelistResolver("Structure", function(
		_attackerEntity: number,
		_attackerKind: any,
		attackerModel: Model?
	): { Instance }
		local whitelistInstances = {} :: { Instance }

		for _, enemyEntity in ipairs(self._enemyEntityFactory:QueryAliveEntities()) do
			local enemyModel = self._enemyInstanceFactory:GetInstance(enemyEntity)
			if enemyModel ~= nil and enemyModel.Parent ~= nil and enemyModel ~= attackerModel then
				table.insert(whitelistInstances, enemyModel)
			end
		end

		return whitelistInstances
	end)

	-- Wire the projectile resolver to enemy and structure contexts so attacks can resolve live targets.
	self._combatServices.ProjectileService:ConfigureStructureBulletResolver(
		StructureProjectileResolverFactory.Create({
			StructureInstanceFactory = self._instanceFactory,
			EnemyContext = self._enemyContext,
			EnemyEntityFactory = self._enemyEntityFactory,
			EnemyInstanceFactory = self._enemyInstanceFactory,
		})
	)

	self._configuredCombatServices = true
end

-- Builds the stable combat handle, preferring the structure's configured id when present.
function StructureCombatAdapterService:_BuildActorHandle(entity: number): string
	local identity = self._entityFactory:GetIdentity(entity)
	if identity ~= nil and type(identity.StructureId) == "string" then
		return "Structure:" .. identity.StructureId
	end
	return "Structure:" .. tostring(entity)
end

-- Builds the fact snapshot consumed by structure behavior nodes on each combat tick.
function StructureCombatAdapterService:_BuildFacts(entity: number, currentTime: number): { [string]: any }
	self:_RefreshCheapFactGroupDirtiness(entity)
	return RuntimeFactCache.Resolve(self._cachedFactsByEntity, entity, currentTime, {
		DefaultCheapFactGroupRefreshIntervalSeconds = FACT_GROUP_CACHE_REFRESH_INTERVAL_SECONDS,
		RefreshIntervalSeconds = FACT_CACHE_REFRESH_INTERVAL_SECONDS,
		CheapFactGroups = self._factsResolver.BuildCheapFactGroups(entity),
		ValidateCachedTarget = function(
			cachedTargetState: {
				TargetEntity: number?,
				TargetKind: string?,
				TargetPosition: Vector3?,
			},
			cheapFacts: { [string]: any }
		): { TargetEntity: number?, TargetKind: string?, TargetPosition: Vector3? }?
			return self._factsResolver.ValidateCachedTarget(cachedTargetState, cheapFacts)
		end,
		ReacquireTarget = function(
			cheapFacts: { [string]: any }
		): { TargetEntity: number?, TargetKind: string?, TargetPosition: Vector3? }?
			return self._factsResolver.ReacquireTarget(cheapFacts)
		end,
		BuildFactSnapshot = function(
			cheapFacts: { [string]: any },
			targetState: {
				TargetEntity: number?,
				TargetKind: string?,
				TargetPosition: Vector3?,
			}
		): { [string]: any }
			return self._factsResolver.BuildFactSnapshot(cheapFacts, targetState)
		end,
		GetActorPosition = function(cheapFacts: { [string]: any }): Vector3?
			return cheapFacts.ActorPosition
		end,
	})
end

function StructureCombatAdapterService:_RefreshCheapFactGroupDirtiness(entity: number)
	local cacheRecord = RuntimeFactCache.GetRecord(self._cachedFactsByEntity, entity)
	if cacheRecord == nil then
		return
	end

	local currentPosition = self._entityFactory:GetPosition(entity)
	local spatialGroup = cacheRecord.CheapFactGroups[CHEAP_FACT_GROUP_SPATIAL]
	if spatialGroup ~= nil and _HasPositionChanged(spatialGroup.Facts.ActorPosition, currentPosition) then
		RuntimeFactCache.MarkCheapFactGroupDirty(self._cachedFactsByEntity, entity, CHEAP_FACT_GROUP_SPATIAL)
	end

	if self._entityFactory:IsDirty(entity) then
		local attackStats = self._entityFactory:GetAttackStats(entity)
		local attackRange = if attackStats ~= nil then attackStats.AttackRange else nil
		local combatStatsGroup = cacheRecord.CheapFactGroups[CHEAP_FACT_GROUP_COMBAT_STATS]
		if combatStatsGroup ~= nil and combatStatsGroup.Facts.AttackRange ~= attackRange then
			RuntimeFactCache.MarkCheapFactGroupDirty(
				self._cachedFactsByEntity,
				entity,
				CHEAP_FACT_GROUP_COMBAT_STATS
			)
		end
	end
end

function StructureCombatAdapterService:_ClearCachedFacts(entity: number)
	RuntimeFactCache.Clear(self._cachedFactsByEntity, entity)
end

function StructureCombatAdapterService:_ClearCachedExecutorServices(entity: number)
	self._cachedExecutorServicesByEntity[entity] = nil
end

function StructureCombatAdapterService:_GetOrCreateCachedExecutorServices(entity: number): { [string]: any }
	local cachedServices = self._cachedExecutorServicesByEntity[entity]
	if cachedServices ~= nil then
		return cachedServices
	end

	local identity = self._entityFactory:GetIdentity(entity)
	local stasisConfig = nil
	if identity ~= nil then
		stasisConfig = StructureConfig.STRUCTURES[identity.StructureType]
	end

	cachedServices = {
		StructureEntityFactory = self._structureFactoryProxyResolver.CreateProxy(entity),
		EnemyEntityFactory = self._enemyEntityFactory,
		CombatPerceptionService = self._perceptionResolver.CreateProxy(),
		CurrentTime = 0,
		ProjectileService = self._projectileProxyResolver.CreateProxy(entity),
		StatusService = self._combatServices.StatusService,
		StatusSourceHandle = self:_BuildActorHandle(entity),
		StasisConfig = stasisConfig,
	}
	self._cachedExecutorServicesByEntity[entity] = cachedServices
	return cachedServices
end

-- Builds the service map exposed to structure behavior executors for the current tick.
function StructureCombatAdapterService:_BuildServices(
	entity: number,
	currentTime: number,
	tickId: number?,
	_frameContext: any?
): { [string]: any }
	local cachedServices = self:_GetOrCreateCachedExecutorServices(entity)
	cachedServices.CurrentTime = currentTime
	cachedServices.TickId = if type(tickId) == "number" then tickId else nil
	return cachedServices
end

return StructureCombatAdapterService
