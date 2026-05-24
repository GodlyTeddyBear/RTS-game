--!strict

local ServerStorage = game:GetService("ServerStorage")

local BaseECSReplicationService = require(ServerStorage.Utilities.ECSUtilities.BaseECSReplicationService)

local UnitECSReplicationService = {}
UnitECSReplicationService.__index = UnitECSReplicationService
setmetatable(UnitECSReplicationService, { __index = BaseECSReplicationService })

function UnitECSReplicationService.new()
	local self = setmetatable(BaseECSReplicationService.new("Unit"), UnitECSReplicationService)
	self._clientSignals = nil
	return self
end

function UnitECSReplicationService:_GetComponentRegistryName(): string
	return "UnitComponentRegistry"
end

function UnitECSReplicationService:_GetEntityFactoryName(): string
	return "UnitEntityFactory"
end

function UnitECSReplicationService:_OnInit(registry: any, _name: string)
	self._clientSignals = registry:Get("ClientSignals")
	assert(self._clientSignals ~= nil, "UnitECSReplicationService: missing ClientSignals")
end

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
		},
	}
end

function UnitECSReplicationService:_RegisterReplicatedSurface(_registry: any)
	for _, entity in ipairs(self:GetEntityFactoryOrThrow():QueryActiveEntities()) do
		self:RegisterUnitEntity(entity)
	end
end

function UnitECSReplicationService:RegisterUnitEntity(entity: number)
	local components = self:GetComponentsOrThrow()

	self:RegisterNetworkedEntity(entity)
	self:RegisterReliableComponent(entity, components.IdentityComponent)
	self:RegisterReliableComponent(entity, components.HealthComponent)
	self:RegisterReliableComponent(entity, components.AnimationStateComponent)
	self:RegisterReliableComponent(entity, components.AnimationLoopingComponent)
	self:RegisterReliableComponent(entity, components.ActiveTag)
end

function UnitECSReplicationService:UnregisterUnitEntity(entity: number)
	self:StopReplicatingEntity(entity)
end

function UnitECSReplicationService:_SendBootstrap(player: Player, payload: any)
	self._clientSignals.UnitBootstrap:Fire(player, payload)
end

function UnitECSReplicationService:_SendReliable(player: Player, payload: any)
	self._clientSignals.UnitReliable:Fire(player, payload)
end

function UnitECSReplicationService:_SendUnreliable(player: Player, payload: any)
	self._clientSignals.UnitUnreliable:Fire(player, payload)
end

function UnitECSReplicationService:_SendEntity(player: Player, payload: any)
	self._clientSignals.UnitEntity:Fire(player, payload)
end

return UnitECSReplicationService
