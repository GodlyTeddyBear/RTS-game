--!strict

local ServerStorage = game:GetService("ServerStorage")

local BaseECSReplicationService = require(ServerStorage.Utilities.ECSUtilities.BaseECSReplicationService)

local EnemyECSReplicationService = {}
EnemyECSReplicationService.__index = EnemyECSReplicationService
setmetatable(EnemyECSReplicationService, { __index = BaseECSReplicationService })

function EnemyECSReplicationService.new()
	local self = setmetatable(BaseECSReplicationService.new("Enemy"), EnemyECSReplicationService)
	self._clientSignals = nil
	return self
end

function EnemyECSReplicationService:_GetComponentRegistryName(): string
	return "EnemyComponentRegistry"
end

function EnemyECSReplicationService:_GetEntityFactoryName(): string
	return "EnemyEntityFactory"
end

function EnemyECSReplicationService:_OnInit(registry: any, _name: string)
	self._clientSignals = registry:Get("ClientSignals")
	assert(self._clientSignals ~= nil, "EnemyECSReplicationService: missing ClientSignals")
end

function EnemyECSReplicationService:_GetSharedSchema()
	local components = self:GetComponentsOrThrow()

	return {
		sharedComponents = {
			components.IdentityComponent,
			components.HealthComponent,
		},
		sharedTags = {
			components.AliveTag,
		},
	}
end

function EnemyECSReplicationService:_RegisterReplicatedSurface(_registry: any)
	for _, entity in ipairs(self:GetEntityFactoryOrThrow():QueryAliveEntities()) do
		self:RegisterEnemyEntity(entity)
	end
end

function EnemyECSReplicationService:RegisterEnemyEntity(entity: number)
	local components = self:GetComponentsOrThrow()

	self:RegisterNetworkedEntity(entity)
	self:RegisterReliableComponent(entity, components.IdentityComponent)
	self:RegisterReliableComponent(entity, components.HealthComponent)
	self:RegisterReliableComponent(entity, components.AliveTag)
end

function EnemyECSReplicationService:UnregisterEnemyEntity(entity: number)
	self:StopReplicatingEntity(entity)
end

function EnemyECSReplicationService:_SendBootstrap(player: Player, payload: any)
	self._clientSignals.EnemyBootstrap:Fire(player, payload)
end

function EnemyECSReplicationService:_SendReliable(player: Player, payload: any)
	self._clientSignals.EnemyReliable:Fire(player, payload)
end

function EnemyECSReplicationService:_SendUnreliable(player: Player, payload: any)
	self._clientSignals.EnemyUnreliable:Fire(player, payload)
end

function EnemyECSReplicationService:_SendEntity(player: Player, payload: any)
	self._clientSignals.EnemyEntity:Fire(player, payload)
end

return EnemyECSReplicationService
