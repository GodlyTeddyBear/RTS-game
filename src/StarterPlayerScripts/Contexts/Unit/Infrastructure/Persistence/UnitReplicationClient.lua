--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GoodSignal = require(ReplicatedStorage.Packages.Goodsignal)
local EntityReplicationClient = require(script.Parent.Parent.Parent.Parent.Entity.Infrastructure.Persistence.EntityReplicationClient)

export type TUnitReplicatedState = {
	UnitGuid: string,
	UnitId: string,
	CurrentHealth: number,
	MaxHealth: number,
	AnimationState: string?,
	IsAnimationLooping: boolean?,
	IsActive: boolean,
	IsGoalReached: boolean,
}

local UnitReplicationClient = {}
UnitReplicationClient.__index = UnitReplicationClient

local IDENTITY_ECS_NAME = "Entity.Identity"
local HEALTH_ECS_NAME = "Entity.Health"
local ANIMATION_STATE_ECS_NAME = "Unit.AnimationState"
local ANIMATION_LOOPING_ECS_NAME = "Unit.AnimationLooping"
local ACTIVE_TAG_ECS_NAME = "Entity.ActiveTag"
local GOAL_REACHED_TAG_ECS_NAME = "Unit.GoalReachedTag"

function UnitReplicationClient.new()
	local self = setmetatable({}, UnitReplicationClient)
	self.StateChanged = GoodSignal.new()
	self._entityReplicationClient = EntityReplicationClient.new()
	self._unitStateByGuid = {}
	self._stateConnection = nil
	return self
end

function UnitReplicationClient:Init()
	self._entityReplicationClient:Init()
end

function UnitReplicationClient:Start()
	self._entityReplicationClient:Start()
	self._stateConnection = self._entityReplicationClient:ObserveStateChanged(function()
		self:_RebuildUnitStateIndex()
	end)
end

function UnitReplicationClient:GetUnitState(unitGuid: string): TUnitReplicatedState?
	return self._unitStateByGuid[unitGuid]
end

function UnitReplicationClient:ObserveUnitStateChanged(callback: (unitGuid: string) -> ())
	return self.StateChanged:Connect(callback)
end

function UnitReplicationClient:Destroy()
	if self._stateConnection ~= nil then
		self._stateConnection:Disconnect()
		self._stateConnection = nil
	end

	if self.StateChanged ~= nil then
		self.StateChanged:DisconnectAll()
	end

	self._entityReplicationClient:Destroy()
	table.clear(self._unitStateByGuid)
end

function UnitReplicationClient:_RebuildUnitStateIndex()
	local world = self._entityReplicationClient:GetWorldOrThrow()
	local components = self._entityReplicationClient:GetComponentsOrThrow()
	local byECSName = components.ByECSName or {}
	local nextStateByGuid = {}
	local changedUnitGuids = {}
	local previousStateByGuid = self._unitStateByGuid

	local identityComponent = byECSName[IDENTITY_ECS_NAME]
	local healthComponent = byECSName[HEALTH_ECS_NAME]
	if identityComponent == nil or healthComponent == nil then
		self._unitStateByGuid = {}
		return
	end

	for entity, identity, health in world:query(identityComponent, healthComponent):iter() do
		if type(identity) ~= "table" or identity.EntityKind ~= "Unit" or type(identity.EntityId) ~= "string" then
			continue
		end
		if type(health) ~= "table" then
			continue
		end

		local unitGuid = identity.EntityId
		local animationState = self:_GetOptional(world, entity, byECSName[ANIMATION_STATE_ECS_NAME])
		local animationLooping = self:_GetOptional(world, entity, byECSName[ANIMATION_LOOPING_ECS_NAME])

		local nextState = table.freeze({
			UnitGuid = unitGuid,
			UnitId = identity.DefinitionId or "Unit",
			CurrentHealth = health.Current or 0,
			MaxHealth = health.Max or 0,
			AnimationState = if type(animationState) == "string" then animationState else nil,
			IsAnimationLooping = if type(animationLooping) == "boolean" then animationLooping else nil,
			IsActive = self:_HasOptional(world, entity, byECSName[ACTIVE_TAG_ECS_NAME]),
			IsGoalReached = self:_HasOptional(world, entity, byECSName[GOAL_REACHED_TAG_ECS_NAME]),
		})

		nextStateByGuid[unitGuid] = nextState

		local previousState = previousStateByGuid[unitGuid]
		if previousState == nil
			or previousState.UnitId ~= nextState.UnitId
			or previousState.CurrentHealth ~= nextState.CurrentHealth
			or previousState.MaxHealth ~= nextState.MaxHealth
			or previousState.AnimationState ~= nextState.AnimationState
			or previousState.IsAnimationLooping ~= nextState.IsAnimationLooping
			or previousState.IsActive ~= nextState.IsActive
			or previousState.IsGoalReached ~= nextState.IsGoalReached
		then
			changedUnitGuids[unitGuid] = true
		end
	end

	for unitGuid in previousStateByGuid do
		if nextStateByGuid[unitGuid] == nil then
			changedUnitGuids[unitGuid] = true
		end
	end

	self._unitStateByGuid = nextStateByGuid
	for unitGuid in changedUnitGuids do
		self.StateChanged:Fire(unitGuid)
	end
end

function UnitReplicationClient:_GetOptional(world: any, entity: any, componentId: any): any
	return if componentId ~= nil then world:get(entity, componentId) else nil
end

function UnitReplicationClient:_HasOptional(world: any, entity: any, tagId: any): boolean
	return tagId ~= nil and world:has(entity, tagId)
end

return UnitReplicationClient
