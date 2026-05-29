--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GoodSignal = require(ReplicatedStorage.Packages.Goodsignal)
local EntityReplicationClient = require(script.Parent.Parent.Parent.Parent.Entity.Infrastructure.Persistence.EntityReplicationClient)

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

local IDENTITY_ECS_NAME = "Entity.Identity"
local HEALTH_ECS_NAME = "Entity.Health"
local ROLE_ECS_NAME = "Enemy.Role"
local MOVE_SPEED_ECS_NAME = "Enemy.CurrentMoveSpeed"
local ANIMATION_STATE_ECS_NAME = "Enemy.AnimationState"
local ANIMATION_LOOPING_ECS_NAME = "Enemy.AnimationLooping"
local ALIVE_TAG_ECS_NAME = "Enemy.AliveTag"
local GOAL_REACHED_TAG_ECS_NAME = "Enemy.GoalReachedTag"

function EnemyReplicationClient.new()
	local self = setmetatable({}, EnemyReplicationClient)
	self.StateChanged = GoodSignal.new()
	self._entityReplicationClient = EntityReplicationClient.new()
	self._enemyStateById = {}
	self._stateConnection = nil
	return self
end

function EnemyReplicationClient:Init()
	self._entityReplicationClient:Init()
end

function EnemyReplicationClient:Start()
	self._entityReplicationClient:Start()
	self._stateConnection = self._entityReplicationClient:ObserveStateChanged(function()
		self:_RebuildEnemyStateIndex()
	end)
end

function EnemyReplicationClient:GetEnemyState(enemyId: string): TEnemyReplicatedState?
	return self._enemyStateById[enemyId]
end

function EnemyReplicationClient:ObserveEnemyStateChanged(callback: (enemyId: string) -> ())
	return self.StateChanged:Connect(callback)
end

function EnemyReplicationClient:Destroy()
	if self._stateConnection ~= nil then
		self._stateConnection:Disconnect()
		self._stateConnection = nil
	end

	if self.StateChanged ~= nil then
		self.StateChanged:DisconnectAll()
	end

	self._entityReplicationClient:Destroy()
	table.clear(self._enemyStateById)
end

function EnemyReplicationClient:_RebuildEnemyStateIndex()
	local world = self._entityReplicationClient:GetWorldOrThrow()
	local components = self._entityReplicationClient:GetComponentsOrThrow()
	local byECSName = components.ByECSName or {}
	local nextStateById = {}
	local changedEnemyIds = {}
	local previousStateById = self._enemyStateById

	local identityComponent = byECSName[IDENTITY_ECS_NAME]
	local healthComponent = byECSName[HEALTH_ECS_NAME]
	if identityComponent == nil or healthComponent == nil then
		self._enemyStateById = {}
		return
	end

	for entity, identity, health in world:query(identityComponent, healthComponent):iter() do
		if type(identity) ~= "table" or identity.EntityKind ~= "Enemy" or type(identity.EntityId) ~= "string" then
			continue
		end
		if type(health) ~= "table" then
			continue
		end

		local enemyId = identity.EntityId
		local roleState = self:_GetOptional(world, entity, byECSName[ROLE_ECS_NAME])
		local moveSpeedState = self:_GetOptional(world, entity, byECSName[MOVE_SPEED_ECS_NAME])
		local animationState = self:_GetOptional(world, entity, byECSName[ANIMATION_STATE_ECS_NAME])
		local animationLooping = self:_GetOptional(world, entity, byECSName[ANIMATION_LOOPING_ECS_NAME])
		local hasAliveTag = self:_HasOptional(world, entity, byECSName[ALIVE_TAG_ECS_NAME])
		local hasGoalReachedTag = self:_HasOptional(world, entity, byECSName[GOAL_REACHED_TAG_ECS_NAME])

		local nextState = table.freeze({
			EnemyId = enemyId,
			Role = if type(roleState) == "table" then roleState.Role else identity.DefinitionId,
			WaveNumber = if type(roleState) == "table" then roleState.WaveNumber else nil,
			CurrentHealth = health.Current or 0,
			MaxHealth = health.Max or 0,
			CurrentMoveSpeed = if type(moveSpeedState) == "table" then moveSpeedState.Value else nil,
			AnimationState = if type(animationState) == "string" then animationState else nil,
			IsAnimationLooping = if type(animationLooping) == "boolean" then animationLooping else nil,
			IsAlive = hasAliveTag,
			IsGoalReached = hasGoalReachedTag,
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

function EnemyReplicationClient:_GetOptional(world: any, entity: any, componentId: any): any
	if componentId == nil then
		return nil
	end

	return world:get(entity, componentId)
end

function EnemyReplicationClient:_HasOptional(world: any, entity: any, tagId: any): boolean
	if tagId == nil then
		return false
	end

	return world:has(entity, tagId)
end

return EnemyReplicationClient
