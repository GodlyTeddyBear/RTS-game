--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GoodSignal = require(ReplicatedStorage.Packages.Goodsignal)
require(ReplicatedStorage.Utilities.Replecs)
local JECS = require(ReplicatedStorage.Packages.JECS)
local Knit = require(ReplicatedStorage.Packages.Knit)
local BaseECSReplicationClient = require(ReplicatedStorage.Utilities.BaseECSReplicationClient)

type TBootstrapPayload = BaseECSReplicationClient.TBootstrapPayload
type TReplicationPacketPayload = BaseECSReplicationClient.TReplicationPacketPayload

export type TEnemyReplicatedState = {
	EnemyId: string,
	Role: string?,
	WaveNumber: number?,
	CurrentHealth: number,
	MaxHealth: number,
	CurrentMoveSpeed: number?,
	AnimationState: string?,
	IsAnimationLooping: boolean?,
	IsAlive: boolean,
	IsGoalReached: boolean,
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

	local currentMoveSpeedComponent = world:component()
	_NameEntity(world, currentMoveSpeedComponent, "Enemy.CurrentMoveSpeed")

	local roleComponent = world:component()
	_NameEntity(world, roleComponent, "Enemy.Role")

	local animationStateComponent = world:component()
	_NameEntity(world, animationStateComponent, "Enemy.AnimationState")

	local animationLoopingComponent = world:component()
	_NameEntity(world, animationLoopingComponent, "Enemy.AnimationLooping")

	local aliveTag = world:entity()
	_NameEntity(world, aliveTag, "Enemy.AliveTag")

	local goalReachedTag = world:entity()
	_NameEntity(world, goalReachedTag, "Enemy.GoalReachedTag")

	return table.freeze({
		IdentityComponent = identityComponent,
		HealthComponent = healthComponent,
		CurrentMoveSpeedComponent = currentMoveSpeedComponent,
		RoleComponent = roleComponent,
		AnimationStateComponent = animationStateComponent,
		AnimationLoopingComponent = animationLoopingComponent,
		AliveTag = aliveTag,
		GoalReachedTag = goalReachedTag,
	})
end

function EnemyReplicationClient:_GetSharedSchema()
	local components = self:GetComponentsOrThrow()

	return {
		sharedComponents = {
			components.IdentityComponent,
			components.HealthComponent,
			components.CurrentMoveSpeedComponent,
			components.RoleComponent,
			components.AnimationStateComponent,
			components.AnimationLoopingComponent,
		},
		sharedTags = {
			components.AliveTag,
			components.GoalReachedTag,
		},
	}
end

function EnemyReplicationClient:_RegisterReplicatedSurface()
	self:_RebuildEnemyStateIndex()
end

function EnemyReplicationClient:HandleBootstrap(payload: TBootstrapPayload): boolean
	local handled = BaseECSReplicationClient.HandleBootstrap(self, payload)
	self:_RebuildEnemyStateIndex()
	return handled
end

function EnemyReplicationClient:HandleReliable(payload: TReplicationPacketPayload)
	BaseECSReplicationClient.HandleReliable(self, payload)
	self:_RebuildEnemyStateIndex()
end

function EnemyReplicationClient:HandleUnreliable(payload: TReplicationPacketPayload)
	BaseECSReplicationClient.HandleUnreliable(self, payload)
	self:_RebuildEnemyStateIndex()
end

function EnemyReplicationClient:HandleEntity(payload: TReplicationPacketPayload)
	BaseECSReplicationClient.HandleEntity(self, payload)
	self:_RebuildEnemyStateIndex()
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
		local currentMoveSpeed = world:get(entity, components.CurrentMoveSpeedComponent)
		local roleState = world:get(entity, components.RoleComponent)
		local animationState = world:get(entity, components.AnimationStateComponent)
		local animationLooping = world:get(entity, components.AnimationLoopingComponent)
		local roleName = if type(roleState) == "table" and type(roleState.Role) == "string"
			then roleState.Role
			else identity.Role
		local nextState = table.freeze({
			EnemyId = enemyId,
			Role = roleName,
			WaveNumber = identity.WaveNumber,
			CurrentHealth = health.Current or 0,
			MaxHealth = health.Max or 0,
			CurrentMoveSpeed = if type(currentMoveSpeed) == "table" then currentMoveSpeed.Value else nil,
			AnimationState = if type(animationState) == "string" then animationState else nil,
			IsAnimationLooping = if type(animationLooping) == "boolean" then animationLooping else nil,
			IsAlive = world:has(entity, components.AliveTag),
			IsGoalReached = world:has(entity, components.GoalReachedTag),
		})

		nextStateById[enemyId] = nextState

		local previousState = previousStateById[enemyId]
		if previousState == nil
			or previousState.Role ~= nextState.Role
			or previousState.WaveNumber ~= nextState.WaveNumber
			or previousState.CurrentHealth ~= nextState.CurrentHealth
			or previousState.MaxHealth ~= nextState.MaxHealth
			or previousState.CurrentMoveSpeed ~= nextState.CurrentMoveSpeed
			or previousState.AnimationState ~= nextState.AnimationState
			or previousState.IsAnimationLooping ~= nextState.IsAnimationLooping
			or previousState.IsAlive ~= nextState.IsAlive
			or previousState.IsGoalReached ~= nextState.IsGoalReached
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
