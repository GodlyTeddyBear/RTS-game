--!strict

--[=[
    @class UnitCombatAdapterService
    Bridges unit entities into the combat runtime and exposes the passive unit behavior adapter.
    @server
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Result = require(ReplicatedStorage.Utilities.Result)
local BehaviorConfig = require(ReplicatedStorage.Contexts.Combat.Config.BehaviorConfig)
local Nodes = require(script.Parent.Parent.BehaviorSystem.Nodes)
local Executors = require(script.Parent.Parent.BehaviorSystem.Executors)
local UnitIdleBehavior = require(script.Parent.Parent.BehaviorSystem.Behaviors.UnitIdleBehavior)

local UnitCombatAdapterService = {}
UnitCombatAdapterService.__index = UnitCombatAdapterService

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
end

-- Registers the unit actor type so the combat runtime can instantiate the passive unit behavior tree.
--[=[
    @within UnitCombatAdapterService
    Registers the unit actor type with the combat runtime.
    @return Result.Result<boolean> -- Whether the actor type registration succeeded.
]=]
function UnitCombatAdapterService:RegisterActorType(): Result.Result<boolean>
	-- Unit actors use the shared combat contract because they do not need custom facts or executors.
	return self._combatContext:RegisterActorType({
		ActorType = "Unit",
		Conditions = Nodes.Conditions,
		Commands = Nodes.Commands,
		Executors = Executors,
		SemanticRequirements = {
			FactsDependOnPolling = false,
			AttributesDependOnProjection = false,
		},
		RuntimeOwner = self._runtimeOwner,
	})
end

-- Registers one unit entity as a runtime actor and builds its per-tick adapter hooks.
--[=[
    @within UnitCombatAdapterService
    Registers one unit entity with the combat runtime.
    @param entity number -- Unit entity id to register.
    @return Result.Result<string> -- Actor handle for the registered unit.
]=]
function UnitCombatAdapterService:RegisterActor(entity: number): Result.Result<string>
	-- Build the adapter directly from the entity snapshot so the runtime can tick it without extra lookups.
	return self._combatContext:RegisterCombatActor({
		ActorType = "Unit",
		ActorHandle = self:_BuildActorHandle(entity),
		BehaviorDefinition = UnitIdleBehavior,
		TickInterval = BehaviorConfig.DEFAULT.TickInterval,
		Adapter = {
			-- Keep the actor alive only while the backing entity still exists in the unit factory.
			IsActive = function(): boolean
				return self._entityFactory:IsActive(entity)
			end,
			-- Use the same handle that was registered so runtime labels stay stable.
			GetActorLabel = function(): string?
				return self:_BuildActorHandle(entity)
			end,
			-- Units do not contribute combat facts, so the behavior tree receives an empty snapshot.
			BuildFacts = function(_currentTime: number): { [string]: any }
				return {}
			end,
			-- Expose the current time and factory so the idle behavior can read unit state on demand.
			BuildServices = function(currentTime: number): { [string]: any }
				return {
					CurrentTime = currentTime,
					UnitEntityFactory = self._entityFactory,
				}
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
	return self._combatContext:UnregisterCombatActor(self:_BuildActorHandle(entity))
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

return UnitCombatAdapterService
