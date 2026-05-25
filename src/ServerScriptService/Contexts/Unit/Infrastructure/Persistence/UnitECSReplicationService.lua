--!strict

--[=[
    @class UnitECSReplicationService
    Replicates the authoritative unit ECS surface to clients through the UnitContext remote signals.

    @server
]=]

local ServerStorage = game:GetService("ServerStorage")

local BaseECSReplicationService = require(ServerStorage.Utilities.ECSUtilities.BaseECSReplicationService)

local UnitECSReplicationService = {}
UnitECSReplicationService.__index = UnitECSReplicationService
setmetatable(UnitECSReplicationService, { __index = BaseECSReplicationService })

-- Creates the replication service bound to the Unit namespace.
function UnitECSReplicationService.new()
	local self = setmetatable(BaseECSReplicationService.new("Unit"), UnitECSReplicationService)
	self._clientSignals = nil
	return self
end

-- Points the replication service at the unit component registry.
function UnitECSReplicationService:_GetComponentRegistryName(): string
	return "UnitComponentRegistry"
end

-- Points the replication service at the unit entity factory.
function UnitECSReplicationService:_GetEntityFactoryName(): string
	return "UnitEntityFactory"
end

-- Grabs the client signal bundle used to deliver bootstrap and packet payloads.
function UnitECSReplicationService:_OnInit(registry: any, _name: string)
	self._clientSignals = registry:Get("ClientSignals")
	assert(self._clientSignals ~= nil, "UnitECSReplicationService: missing ClientSignals")
end

-- Returns the shared components and tags that should be replicated to clients.
function UnitECSReplicationService:_GetSharedSchema()
	local components = self:GetComponentsOrThrow()

	return {
		sharedComponents = {
			components.IdentityComponent,
			components.HealthComponent,
			components.AnimationStateComponent,
			components.AnimationLoopingComponent,
		},
		sharedTags = {
			components.ActiveTag,
			components.GoalReachedTag,
		},
	}
end

-- Registers every active unit for replication when the surface is first attached.
function UnitECSReplicationService:_RegisterReplicatedSurface(_registry: any)
	for _, entity in ipairs(self:GetEntityFactoryOrThrow():QueryActiveEntities()) do
		self:RegisterUnitEntity(entity)
	end
end

-- Registers a single active unit entity and the components that clients need to animate and display it.
function UnitECSReplicationService:RegisterUnitEntity(entity: number)
	local components = self:GetComponentsOrThrow()

	self:RegisterNetworkedEntity(entity)
	self:RegisterReliableComponent(entity, components.IdentityComponent)
	self:RegisterReliableComponent(entity, components.HealthComponent)
	self:RegisterReliableComponent(entity, components.AnimationStateComponent)
	self:RegisterReliableComponent(entity, components.AnimationLoopingComponent)
	self:RegisterReliableComponent(entity, components.ActiveTag)
	self:RegisterReliableComponent(entity, components.GoalReachedTag)
end

-- Stops replicating the requested unit entity.
function UnitECSReplicationService:UnregisterUnitEntity(entity: number)
	self:StopReplicatingEntity(entity)
end

-- Fires the bootstrap payload through the UnitContext client signal.
function UnitECSReplicationService:_SendBootstrap(player: Player, payload: any)
	self._clientSignals.UnitBootstrap:Fire(player, payload)
end

-- Fires reliable unit packets through the UnitContext client signal.
function UnitECSReplicationService:_SendReliable(player: Player, payload: any)
	self._clientSignals.UnitReliable:Fire(player, payload)
end

-- Fires unreliable unit packets through the UnitContext client signal.
function UnitECSReplicationService:_SendUnreliable(player: Player, payload: any)
	self._clientSignals.UnitUnreliable:Fire(player, payload)
end

-- Fires entity-level unit packets through the UnitContext client signal.
function UnitECSReplicationService:_SendEntity(player: Player, payload: any)
	self._clientSignals.UnitEntity:Fire(player, payload)
end

return UnitECSReplicationService
