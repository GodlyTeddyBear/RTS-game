--!strict

--[=[
    @class UnitCombatAdapterService
    Bridges unit entities into the combat runtime and exposes the passive unit behavior adapter.
    @server
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local AI = require(ServerStorage.Utilities.ContextUtilities.AI)
local RuntimeFactCache = require(ServerStorage.Utilities.ContextUtilities.RuntimeFactCache)
local Result = require(ReplicatedStorage.Utilities.Result)
local UnitConfig = require(ReplicatedStorage.Contexts.Unit.Config.UnitConfig)
local Nodes = require(script.Parent.Parent.BehaviorSystem.Nodes)
local Executors = require(script.Parent.Parent.BehaviorSystem.Executors)
local UnitTypes = require(ReplicatedStorage.Contexts.Unit.Types.UnitTypes)
local UnitRuntimeProfiles = require(script.Parent.Parent.Runtime.Profiles.UnitRuntimeProfiles)
local UnitFactsResolverFactory = require(script.Parent.Parent.Runtime.Resolvers.UnitFactsResolverFactory)
local UnitMovementProxyResolverFactory = require(script.Parent.Parent.Runtime.Resolvers.UnitMovementProxyResolverFactory)
local UnitServiceProxyResolverFactory = require(script.Parent.Parent.Runtime.Resolvers.UnitServiceProxyResolverFactory)

type UnitDefinition = UnitTypes.UnitDefinition

local UnitCombatAdapterService = {}
UnitCombatAdapterService.__index = UnitCombatAdapterService

local UnitSemanticRequirements = table.freeze({
	FactsDependOnPolling = false,
	AttributesDependOnProjection = false,
})
local FACT_CACHE_REFRESH_INTERVAL_SECONDS = 0.2
local FACT_GROUP_CACHE_REFRESH_INTERVAL_SECONDS = 1
local CHEAP_FACT_GROUP_NAVIGATION = "Navigation"

-- ── Public ────────────────────────────────────────────────────────────────────

-- Creates a new unit combat adapter service with deferred runtime-owner wiring.
--[=[
    @within UnitCombatAdapterService
    Creates a new unit combat adapter service.
    @return UnitCombatAdapterService -- Service instance used to register unit combat actors.
]=]
function UnitCombatAdapterService.new()
	local self = setmetatable({}, UnitCombatAdapterService)
	self._runtimeOwner = nil
	self._cachedFactsByEntity = {}
	self._cachedExecutorServicesByEntity = {}
	return self
end

-- Resolves the unit entity factory used to build actor adapters.
--[=[
    @within UnitCombatAdapterService
    Resolves the unit context dependencies used by the adapter service.
    @param registry any -- Registry instance supplied by the context bootstrap.
    @param _name string -- Registry key used to register the service.
]=]
function UnitCombatAdapterService:Init(registry: any, _name: string)
	self._entityFactory = registry:Get("UnitEntityFactory")
end

-- Resolves the combat context used to register unit actors.
--[=[
    @within UnitCombatAdapterService
    Resolves the combat dependency used by the adapter service.
    @param registry any -- Registry instance supplied by the context bootstrap.
    @param _name string -- Registry key used to register the service.
]=]
function UnitCombatAdapterService:Start(registry: any, _name: string)
	self._combatContext = registry:Get("CombatContext")
	self._combatServices = self._combatContext:GetCombatRuntimeServices().value
	self._movementProxyResolver = UnitMovementProxyResolverFactory.Create({
		MovementService = self._combatServices.MovementService,
		UnitEntityFactory = self._entityFactory,
	})
	self._factsResolver = UnitFactsResolverFactory.Create({
		UnitEntityFactory = self._entityFactory,
	})
	self._serviceProxyResolver = UnitServiceProxyResolverFactory.Create({
		UnitEntityFactory = self._entityFactory,
		MovementProxyResolver = self._movementProxyResolver,
		GetRuntimeOwner = function()
			return self._runtimeOwner
		end,
	})
end

-- Registers the unit actor type so the combat runtime can instantiate the passive unit behavior tree.
--[=[
    @within UnitCombatAdapterService
    Registers the unit actor type with the combat runtime.
    @return Result.Result<boolean> -- Whether the actor type registration succeeded.
]=]
function UnitCombatAdapterService:RegisterActorType(): Result.Result<boolean>
	return Result.Catch(function()
		AI.ValidateSemanticContract("Unit", UnitSemanticRequirements, nil, {
			RuntimeOwner = self._runtimeOwner,
		})

		return self._combatContext:RegisterActorType({
			ActorType = "Unit",
			Conditions = Nodes.Conditions,
			Commands = Nodes.Commands,
			Executors = Executors,
			SemanticRequirements = UnitSemanticRequirements,
			RuntimeOwner = self._runtimeOwner,
		})
	end, "Unit:RegisterActorType")
end

-- Registers one unit entity as a runtime actor and builds its per-tick adapter hooks.
--[=[
    @within UnitCombatAdapterService
    Registers one unit entity with the combat runtime.
    @param entity number -- Unit entity id to register.
    @return Result.Result<string> -- Actor handle for the registered unit.
]=]
function UnitCombatAdapterService:RegisterActor(entity: number): Result.Result<string>
	local identity = self._entityFactory:GetIdentity(entity)
	assert(identity ~= nil, "UnitCombatAdapterService: missing identity for unit actor")

	local definition = UnitConfig.Definitions[identity.UnitId] :: UnitDefinition?
	assert(definition ~= nil, ("UnitCombatAdapterService: missing config for unit id '%s'"):format(tostring(identity.UnitId)))

	local runtimeProfile = UnitRuntimeProfiles.GetByVariant(definition.RuntimeProfileId)

	-- Build the adapter directly from the entity snapshot so the runtime can tick it without extra lookups.
	return self._combatContext:RegisterCombatActor({
		ActorType = "Unit",
		ActorHandle = self:_BuildActorHandle(entity),
		BehaviorDefinition = runtimeProfile.BehaviorDefinition,
		TickInterval = runtimeProfile.TickInterval,
		Adapter = {
			-- Keep the actor alive only while the backing entity still exists in the unit factory.
			IsActive = function(): boolean
				return self._entityFactory:IsActive(entity)
			end,
			-- Use the same handle that was registered so runtime labels stay stable.
			GetActorLabel = function(): string?
				return self:_BuildActorHandle(entity)
			end,
			BuildFacts = function(_currentTime: number): { [string]: any }
				return self:_BuildFacts(entity, _currentTime)
			end,
			BuildServices = function(currentTime: number, tickId: number?): { [string]: any }
				return self:_BuildServices(entity, currentTime, tickId)
			end,
			OnCancel = function()
				self._movementProxyResolver.CreateProxy(entity):StopMovement(0)
			end,
			OnRemoved = function()
				self:_ClearCachedFacts(entity)
				self:_ClearCachedExecutorServices(entity)
				self._movementProxyResolver.CreateProxy(entity):StopMovement(0)
			end,
			OnActionStateChanged = function(_actionState: any)
				self._entityFactory:MarkDirty(entity)
			end,
		},
	})
end

-- Unregisters one unit actor when its entity leaves the runtime.
--[=[
    @within UnitCombatAdapterService
    Unregisters one unit actor from the combat runtime.
    @param entity number -- Unit entity id to unregister.
    @return Result.Result<boolean> -- Whether the actor was removed successfully.
]=]
function UnitCombatAdapterService:UnregisterActor(entity: number): Result.Result<boolean>
	self:_ClearCachedFacts(entity)
	self:_ClearCachedExecutorServices(entity)
	if self._combatServices ~= nil then
		self._movementProxyResolver.CreateProxy(entity):StopMovement(0)
	end
	return self._combatContext:UnregisterCombatActor(self:_BuildActorHandle(entity))
end

function UnitCombatAdapterService:GetActorHandle(entity: number): string
	return self:_BuildActorHandle(entity)
end

-- Stores the context that owns this adapter so callbacks can resolve back into it.
--[=[
    @within UnitCombatAdapterService
    Stores the runtime owner that owns this adapter service.
    @param runtimeOwner any -- Owning context or runtime object.
]=]
function UnitCombatAdapterService:ConfigureRuntimeOwner(runtimeOwner: any)
	self._runtimeOwner = runtimeOwner
end

-- ── Private ───────────────────────────────────────────────────────────────────

-- Builds the stable combat handle, preferring the unit's configured guid when present.
function UnitCombatAdapterService:_BuildActorHandle(entity: number): string
	local identity = self._entityFactory:GetIdentity(entity)
	if identity ~= nil and type(identity.UnitGuid) == "string" then
		return "Unit:" .. identity.UnitGuid
	end
	return "Unit:" .. tostring(entity)
end

function UnitCombatAdapterService:_BuildFacts(entity: number, currentTime: number): { [string]: any }
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
	})
end

function UnitCombatAdapterService:_BuildServices(
	entity: number,
	currentTime: number,
	tickId: number?
): { [string]: any }
	local cachedServices = self:_GetOrCreateCachedExecutorServices(entity)
	cachedServices.CurrentTime = currentTime
	cachedServices.TickId = if type(tickId) == "number" then tickId else nil
	cachedServices.UnitContext = self._runtimeOwner
	return cachedServices
end

function UnitCombatAdapterService:_RefreshCheapFactGroupDirtiness(entity: number)
	local cacheRecord = RuntimeFactCache.GetRecord(self._cachedFactsByEntity, entity)
	if cacheRecord == nil then
		return
	end

	local pathState = self._entityFactory:GetPathState(entity)
	local hasGoalTarget = pathState ~= nil and pathState.GoalPosition ~= nil
	local navigationGroup = cacheRecord.CheapFactGroups[CHEAP_FACT_GROUP_NAVIGATION]
	if navigationGroup ~= nil and navigationGroup.Facts.HasGoalTarget ~= hasGoalTarget then
		RuntimeFactCache.MarkCheapFactGroupDirty(self._cachedFactsByEntity, entity, CHEAP_FACT_GROUP_NAVIGATION)
	end
end

function UnitCombatAdapterService:_ClearCachedFacts(entity: number)
	RuntimeFactCache.Clear(self._cachedFactsByEntity, entity)
end

function UnitCombatAdapterService:_ClearCachedExecutorServices(entity: number)
	self._cachedExecutorServicesByEntity[entity] = nil
end

function UnitCombatAdapterService:_GetOrCreateCachedExecutorServices(entity: number): { [string]: any }
	local cachedServices = self._cachedExecutorServicesByEntity[entity]
	if cachedServices ~= nil then
		return cachedServices
	end

	cachedServices = self._serviceProxyResolver.BuildServices(entity, 0, nil)
	cachedServices.UnitContext = self._runtimeOwner
	self._cachedExecutorServicesByEntity[entity] = cachedServices
	return cachedServices
end

return UnitCombatAdapterService
