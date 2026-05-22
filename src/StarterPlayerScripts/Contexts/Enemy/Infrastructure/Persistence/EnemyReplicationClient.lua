--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GoodSignal = require(ReplicatedStorage.Packages.Goodsignal)
require(ReplicatedStorage.Utilities.Replecs)
local JECS = require(ReplicatedStorage.Packages.JECS)
local Knit = require(ReplicatedStorage.Packages.Knit)
local BaseECSReplicationClient = require(ReplicatedStorage.Utilities.BaseECSReplicationClient)

export type TEnemyReplicatedState = {
	EnemyId: string,
	CurrentHealth: number,
	MaxHealth: number,
	IsAlive: boolean,
}

local EnemyReplicationClient = {}
EnemyReplicationClient.__index = EnemyReplicationClient
setmetatable(EnemyReplicationClient, { __index = BaseECSReplicationClient })

local function _NameEntity(world: any, entity: any, name: string)
	world:set(entity, JECS.Name, name)
end

function EnemyReplicationClient.new()
	local self = setmetatable(BaseECSReplicationClient.new("Enemy"), EnemyReplicationClient)
	self.StateChanged = GoodSignal.new()
	self._enemyContext = nil
	self._enemyStateById = {}
	return self
end

function EnemyReplicationClient:_BuildComponents(world: any, _replecsLibrary: any)
	local identityComponent = world:component()
	_NameEntity(world, identityComponent, "Enemy.Identity")

	local healthComponent = world:component()
	_NameEntity(world, healthComponent, "Enemy.Health")

	local aliveTag = world:entity()
	_NameEntity(world, aliveTag, "Enemy.AliveTag")

	return table.freeze({
		IdentityComponent = identityComponent,
		HealthComponent = healthComponent,
		AliveTag = aliveTag,
	})
end

function EnemyReplicationClient:_GetSharedSchema()
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

function EnemyReplicationClient:_RegisterReplicatedSurface()
	self:AfterReplication(function()
		self:_RebuildEnemyStateIndex()
	end)
end

function EnemyReplicationClient:_ConnectTransport()
	self._enemyContext = Knit.GetService("EnemyContext")

	local connections = {
		self._enemyContext.EnemyBootstrap:Connect(function(payload)
			self:HandleBootstrap(payload)
		end),
		self._enemyContext.EnemyReliable:Connect(function(payload)
			self:HandleReliable(payload)
		end),
		self._enemyContext.EnemyUnreliable:Connect(function(payload)
			self:HandleUnreliable(payload)
		end),
		self._enemyContext.EnemyEntity:Connect(function(payload)
			self:HandleEntity(payload)
		end),
	}

	return function()
		for _, connection in ipairs(connections) do
			connection:Disconnect()
		end
	end
end

function EnemyReplicationClient:_OnStart()
	assert(self._enemyContext ~= nil, "EnemyReplicationClient: missing EnemyContext")
	self._enemyContext:RequestEnemyReplication()
end

function EnemyReplicationClient:_OnBootstrapCompleted()
	assert(self._enemyContext ~= nil, "EnemyReplicationClient: missing EnemyContext")
	self._enemyContext:AcknowledgeEnemyReplicationBootstrap()
end

function EnemyReplicationClient:GetEnemyState(enemyId: string): TEnemyReplicatedState?
	return self._enemyStateById[enemyId]
end

function EnemyReplicationClient:ObserveEnemyStateChanged(callback: (enemyId: string) -> ())
	return self.StateChanged:Connect(callback)
end

function EnemyReplicationClient:Destroy()
	if self.StateChanged ~= nil then
		self.StateChanged:DisconnectAll()
	end

	BaseECSReplicationClient.Destroy(self)
	self._enemyContext = nil
	table.clear(self._enemyStateById)
end

function EnemyReplicationClient:_RebuildEnemyStateIndex()
	local world = self:GetWorldOrThrow()
	local components = self:GetComponentsOrThrow()
	local nextStateById = {}
	local changedEnemyIds = {}
	local previousStateById = self._enemyStateById

	for entity, identity, health in world:query(components.IdentityComponent, components.HealthComponent):iter() do
		if type(identity) ~= "table" or type(identity.EnemyId) ~= "string" then
			continue
		end
		if type(health) ~= "table" then
			continue
		end

		local enemyId = identity.EnemyId
		local nextState = table.freeze({
			EnemyId = enemyId,
			CurrentHealth = health.Current or 0,
			MaxHealth = health.Max or 0,
			IsAlive = world:has(entity, components.AliveTag),
		})

		nextStateById[enemyId] = nextState

		local previousState = previousStateById[enemyId]
		if previousState == nil
			or previousState.CurrentHealth ~= nextState.CurrentHealth
			or previousState.MaxHealth ~= nextState.MaxHealth
			or previousState.IsAlive ~= nextState.IsAlive
		then
			changedEnemyIds[enemyId] = true
		end
	end

	for enemyId in previousStateById do
		if nextStateById[enemyId] == nil then
			changedEnemyIds[enemyId] = true
		end
	end

	self._enemyStateById = nextStateById

	for enemyId in changedEnemyIds do
		self.StateChanged:Fire(enemyId)
	end
end

return EnemyReplicationClient
