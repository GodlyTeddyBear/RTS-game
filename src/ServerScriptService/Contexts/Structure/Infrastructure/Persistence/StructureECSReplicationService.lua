--!strict

--[=[
    @class StructureECSReplicationService
    Structure-context server replication service that specializes the shared
    ECS replication base for structure entities, binds the context signals
    transport, and registers the structure surface that should be visible to
    clients.
    @server
]=]

local ServerStorage = game:GetService("ServerStorage")

local BaseECSReplicationService = require(ServerStorage.Utilities.ECSUtilities.BaseECSReplicationService)

local StructureECSReplicationService = {}
StructureECSReplicationService.__index = StructureECSReplicationService
setmetatable(StructureECSReplicationService, { __index = BaseECSReplicationService })

function StructureECSReplicationService.new()
	local self = setmetatable(BaseECSReplicationService.new("Structure"), StructureECSReplicationService)
	self._clientSignals = nil
	return self
end

function StructureECSReplicationService:_GetComponentRegistryName(): string
	return "StructureComponentRegistry"
end

function StructureECSReplicationService:_GetEntityFactoryName(): string
	return "StructureEntityFactory"
end

function StructureECSReplicationService:_OnInit(registry: any, _name: string)
	self._clientSignals = registry:Get("ClientSignals")
	assert(self._clientSignals ~= nil, "StructureECSReplicationService: missing ClientSignals")
end

function StructureECSReplicationService:_GetSharedSchema()
	local components = self:GetComponentsOrThrow()

	return {
		sharedComponents = {
			components.IdentityComponent,
			components.HealthComponent,
			components.AnimationStateComponent,
			components.AnimationLoopingComponent,
			components.TargetEnemyIdComponent,
		},
		sharedTags = {
			components.ActiveTag,
		},
	}
end

function StructureECSReplicationService:_RegisterReplicatedSurface(_registry: any)
	for _, entity in ipairs(self:GetEntityFactoryOrThrow():QueryActiveEntities()) do
		self:RegisterStructureEntity(entity)
	end
end

function StructureECSReplicationService:RegisterStructureEntity(entity: number)
	local components = self:GetComponentsOrThrow()

	self:RegisterNetworkedEntity(entity)
	self:RegisterReliableComponent(entity, components.IdentityComponent)
	self:RegisterReliableComponent(entity, components.HealthComponent)
	self:RegisterReliableComponent(entity, components.AnimationStateComponent)
	self:RegisterReliableComponent(entity, components.AnimationLoopingComponent)
	self:RegisterReliableComponent(entity, components.TargetEnemyIdComponent)
	self:RegisterReliableComponent(entity, components.ActiveTag)
end

function StructureECSReplicationService:UnregisterStructureEntity(entity: number)
	self:StopReplicatingEntity(entity)
end

function StructureECSReplicationService:_SendBootstrap(player: Player, payload: any)
	self._clientSignals.StructureBootstrap:Fire(player, payload)
end

function StructureECSReplicationService:_SendReliable(player: Player, payload: any)
	self._clientSignals.StructureReliable:Fire(player, payload)
end

function StructureECSReplicationService:_SendUnreliable(player: Player, payload: any)
	self._clientSignals.StructureUnreliable:Fire(player, payload)
end

function StructureECSReplicationService:_SendEntity(player: Player, payload: any)
	self._clientSignals.StructureEntity:Fire(player, payload)
end

return StructureECSReplicationService
