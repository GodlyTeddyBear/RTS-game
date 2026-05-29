--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GoodSignal = require(ReplicatedStorage.Packages.Goodsignal)
local EntityReplicationClient = require(script.Parent.Parent.Parent.Parent.Entity.Infrastructure.Persistence.EntityReplicationClient)

export type TStructureReplicatedState = {
	StructureId: string,
	StructureType: string,
	CurrentHealth: number,
	MaxHealth: number,
	CurrentBuildWork: number,
	RequiredBuildWork: number,
	BuildPercent: number,
	BuildState: "UnderConstruction" | "Completed",
	AnimationState: string?,
	IsAnimationLooping: boolean?,
	TargetEnemyId: string?,
	IsPlaced: boolean,
	IsUnderConstruction: boolean,
	IsActive: boolean,
}

local StructureReplicationClient = {}
StructureReplicationClient.__index = StructureReplicationClient

local IDENTITY_ECS_NAME = "Entity.Identity"
local HEALTH_ECS_NAME = "Entity.Health"
local CONSTRUCTION_ECS_NAME = "Structure.Construction"
local ANIMATION_STATE_ECS_NAME = "Structure.AnimationState"
local ANIMATION_LOOPING_ECS_NAME = "Structure.AnimationLooping"
local TARGET_ENEMY_ID_ECS_NAME = "Structure.TargetEnemyId"
local PLACED_TAG_ECS_NAME = "Structure.PlacedTag"
local UNDER_CONSTRUCTION_TAG_ECS_NAME = "Structure.UnderConstructionTag"
local OPERATIONAL_TAG_ECS_NAME = "Structure.OperationalTag"

function StructureReplicationClient.new()
	local self = setmetatable({}, StructureReplicationClient)
	self.StateChanged = GoodSignal.new()
	self._entityReplicationClient = EntityReplicationClient.new()
	self._structureStateById = {}
	self._stateConnection = nil
	return self
end

function StructureReplicationClient:Init()
	self._entityReplicationClient:Init()
end

function StructureReplicationClient:Start()
	self._entityReplicationClient:Start()
	self._stateConnection = self._entityReplicationClient:ObserveStateChanged(function()
		self:_RebuildStructureStateIndex()
	end)
end

function StructureReplicationClient:GetStructureState(structureId: string): TStructureReplicatedState?
	return self._structureStateById[structureId]
end

function StructureReplicationClient:ObserveStructureStateChanged(callback: (structureId: string) -> ())
	return self.StateChanged:Connect(callback)
end

function StructureReplicationClient:Destroy()
	if self._stateConnection ~= nil then
		self._stateConnection:Disconnect()
		self._stateConnection = nil
	end
	if self.StateChanged ~= nil then
		self.StateChanged:DisconnectAll()
	end

	self._entityReplicationClient:Destroy()
	table.clear(self._structureStateById)
end

function StructureReplicationClient:_RebuildStructureStateIndex()
	local world = self._entityReplicationClient:GetWorldOrThrow()
	local components = self._entityReplicationClient:GetComponentsOrThrow()
	local byECSName = components.ByECSName or {}
	local identityComponent = byECSName[IDENTITY_ECS_NAME]
	local healthComponent = byECSName[HEALTH_ECS_NAME]
	local constructionComponent = byECSName[CONSTRUCTION_ECS_NAME]
	if identityComponent == nil or healthComponent == nil or constructionComponent == nil then
		self._structureStateById = {}
		return
	end

	local nextStateById = {}
	local changedStructureIds = {}
	local previousStateById = self._structureStateById

	for entity, identity, health, construction in world:query(identityComponent, healthComponent, constructionComponent):iter() do
		if type(identity) ~= "table" or identity.EntityKind ~= "Structure" or type(identity.EntityId) ~= "string" then
			continue
		end
		if type(health) ~= "table" or type(construction) ~= "table" then
			continue
		end

		local structureId = identity.EntityId
		local animationState = self:_GetOptional(world, entity, byECSName[ANIMATION_STATE_ECS_NAME])
		local animationLooping = self:_GetOptional(world, entity, byECSName[ANIMATION_LOOPING_ECS_NAME])
		local targetEnemyId = self:_GetOptional(world, entity, byECSName[TARGET_ENEMY_ID_ECS_NAME])
		local currentBuildWork = construction.CurrentWork or 0
		local requiredBuildWork = construction.RequiredWork or 0
		local buildPercent = if requiredBuildWork > 0
			then math.clamp((currentBuildWork / requiredBuildWork) * 100, 0, 100)
			else 0
		local isUnderConstruction = self:_HasOptional(world, entity, byECSName[UNDER_CONSTRUCTION_TAG_ECS_NAME])

		local nextState = table.freeze({
			StructureId = structureId,
			StructureType = identity.DefinitionId or "Structure",
			CurrentHealth = health.Current or 0,
			MaxHealth = health.Max or 0,
			CurrentBuildWork = currentBuildWork,
			RequiredBuildWork = requiredBuildWork,
			BuildPercent = buildPercent,
			BuildState = if isUnderConstruction then "UnderConstruction" else "Completed",
			AnimationState = if type(animationState) == "string" then animationState else nil,
			IsAnimationLooping = if type(animationLooping) == "boolean" then animationLooping else nil,
			TargetEnemyId = if type(targetEnemyId) == "string" and targetEnemyId ~= "" then targetEnemyId else nil,
			IsPlaced = self:_HasOptional(world, entity, byECSName[PLACED_TAG_ECS_NAME]),
			IsUnderConstruction = isUnderConstruction,
			IsActive = self:_HasOptional(world, entity, byECSName[OPERATIONAL_TAG_ECS_NAME]),
		})

		nextStateById[structureId] = nextState
		local previousState = previousStateById[structureId]
		if previousState == nil
			or previousState.StructureType ~= nextState.StructureType
			or previousState.CurrentHealth ~= nextState.CurrentHealth
			or previousState.MaxHealth ~= nextState.MaxHealth
			or previousState.CurrentBuildWork ~= nextState.CurrentBuildWork
			or previousState.RequiredBuildWork ~= nextState.RequiredBuildWork
			or previousState.BuildPercent ~= nextState.BuildPercent
			or previousState.BuildState ~= nextState.BuildState
			or previousState.AnimationState ~= nextState.AnimationState
			or previousState.IsAnimationLooping ~= nextState.IsAnimationLooping
			or previousState.TargetEnemyId ~= nextState.TargetEnemyId
			or previousState.IsPlaced ~= nextState.IsPlaced
			or previousState.IsUnderConstruction ~= nextState.IsUnderConstruction
			or previousState.IsActive ~= nextState.IsActive
		then
			changedStructureIds[structureId] = true
		end
	end

	for structureId in previousStateById do
		if nextStateById[structureId] == nil then
			changedStructureIds[structureId] = true
		end
	end

	self._structureStateById = nextStateById
	for structureId in changedStructureIds do
		self.StateChanged:Fire(structureId)
	end
end

function StructureReplicationClient:_GetOptional(world: any, entity: any, componentId: any): any
	return if componentId ~= nil then world:get(entity, componentId) else nil
end

function StructureReplicationClient:_HasOptional(world: any, entity: any, tagId: any): boolean
	return tagId ~= nil and world:has(entity, tagId)
end

return StructureReplicationClient
