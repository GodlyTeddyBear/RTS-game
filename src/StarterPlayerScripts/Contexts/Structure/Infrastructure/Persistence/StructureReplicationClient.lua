--!strict

--[=[
    @class StructureReplicationClient
    Structure-context client replication adapter that extends the shared ECS
    client base, connects to `StructureContext`, and rebuilds a typed structure
    state index after each replicated packet so gameplay code can observe
    structure updates without reading model attributes directly.
    @client
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GoodSignal = require(ReplicatedStorage.Packages.Goodsignal)
require(ReplicatedStorage.Utilities.Replecs)
local JECS = require(ReplicatedStorage.Packages.JECS)
local Knit = require(ReplicatedStorage.Packages.Knit)
local BaseECSReplicationClient = require(ReplicatedStorage.Utilities.BaseECSReplicationClient)
local StashPlus = require(ReplicatedStorage.Utilities.StashPlus)

type TBootstrapPayload = BaseECSReplicationClient.TBootstrapPayload
type TReplicationPacketPayload = BaseECSReplicationClient.TReplicationPacketPayload

export type TStructureReplicatedState = {
	StructureId: string,
	StructureType: string,
	CurrentHealth: number,
	MaxHealth: number,
	AnimationState: string?,
	IsAnimationLooping: boolean?,
	TargetEnemyId: string?,
	IsActive: boolean,
}

local StructureReplicationClient = {}
StructureReplicationClient.__index = StructureReplicationClient
setmetatable(StructureReplicationClient, { __index = BaseECSReplicationClient })

local function _NameEntity(world: any, entity: any, name: string)
	world:set(entity, JECS.Name, name)
end

function StructureReplicationClient.new()
	local self = setmetatable(BaseECSReplicationClient.new("Structure"), StructureReplicationClient)
	self.StateChanged = GoodSignal.new()
	self._structureContext = nil
	self._structureStateById = {}
	return self
end

function StructureReplicationClient:_BuildComponents(world: any, _replecsLibrary: any)
	local identityComponent = world:component()
	_NameEntity(world, identityComponent, "Structure.Identity")

	local healthComponent = world:component()
	_NameEntity(world, healthComponent, "Structure.Health")

	local animationStateComponent = world:component()
	_NameEntity(world, animationStateComponent, "Structure.AnimationState")

	local animationLoopingComponent = world:component()
	_NameEntity(world, animationLoopingComponent, "Structure.AnimationLooping")

	local targetEnemyIdComponent = world:component()
	_NameEntity(world, targetEnemyIdComponent, "Structure.TargetEnemyId")

	local activeTag = world:entity()
	_NameEntity(world, activeTag, "Structure.ActiveTag")

	return table.freeze({
		IdentityComponent = identityComponent,
		HealthComponent = healthComponent,
		AnimationStateComponent = animationStateComponent,
		AnimationLoopingComponent = animationLoopingComponent,
		TargetEnemyIdComponent = targetEnemyIdComponent,
		ActiveTag = activeTag,
	})
end

function StructureReplicationClient:_GetSharedSchema()
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

function StructureReplicationClient:_RegisterReplicatedSurface()
	self:_RebuildStructureStateIndex()
end

function StructureReplicationClient:HandleBootstrap(payload: TBootstrapPayload): boolean
	local handled = BaseECSReplicationClient.HandleBootstrap(self, payload)
	self:_RebuildStructureStateIndex()
	return handled
end

function StructureReplicationClient:HandleReliable(payload: TReplicationPacketPayload)
	BaseECSReplicationClient.HandleReliable(self, payload)
	self:_RebuildStructureStateIndex()
end

function StructureReplicationClient:HandleUnreliable(payload: TReplicationPacketPayload)
	BaseECSReplicationClient.HandleUnreliable(self, payload)
	self:_RebuildStructureStateIndex()
end

function StructureReplicationClient:HandleEntity(payload: TReplicationPacketPayload)
	BaseECSReplicationClient.HandleEntity(self, payload)
	self:_RebuildStructureStateIndex()
end

function StructureReplicationClient:_ConnectTransport()
	self._structureContext = Knit.GetService("StructureContext")
	local stash = StashPlus.new()

	stash:AddConnection(self._structureContext.StructureBootstrap:Connect(function(payload)
		self:HandleBootstrap(payload)
	end))
	stash:AddConnection(self._structureContext.StructureReliable:Connect(function(payload)
		self:HandleReliable(payload)
	end))
	stash:AddConnection(self._structureContext.StructureUnreliable:Connect(function(payload)
		self:HandleUnreliable(payload)
	end))
	stash:AddConnection(self._structureContext.StructureEntity:Connect(function(payload)
		self:HandleEntity(payload)
	end))

	return stash
end

function StructureReplicationClient:_OnStart()
	assert(self._structureContext ~= nil, "StructureReplicationClient: missing StructureContext")
	self._structureContext:RequestStructureReplication()
end

function StructureReplicationClient:_OnBootstrapCompleted()
	assert(self._structureContext ~= nil, "StructureReplicationClient: missing StructureContext")
	self._structureContext:AcknowledgeStructureReplicationBootstrap()
end

function StructureReplicationClient:GetStructureState(structureId: string): TStructureReplicatedState?
	return self._structureStateById[structureId]
end

function StructureReplicationClient:ObserveStructureStateChanged(callback: (structureId: string) -> ())
	return self.StateChanged:Connect(callback)
end

function StructureReplicationClient:Destroy()
	if self.StateChanged ~= nil then
		self.StateChanged:DisconnectAll()
	end

	BaseECSReplicationClient.Destroy(self)
	self._structureContext = nil
	table.clear(self._structureStateById)
end

function StructureReplicationClient:_RebuildStructureStateIndex()
	local world = self:GetWorldOrThrow()
	local components = self:GetComponentsOrThrow()
	local nextStateById = {}
	local changedStructureIds = {}
	local previousStateById = self._structureStateById

	for entity, identity, health in world:query(components.IdentityComponent, components.HealthComponent):iter() do
		if type(identity) ~= "table" or type(identity.StructureId) ~= "string" or type(identity.StructureType) ~= "string" then
			continue
		end
		if type(health) ~= "table" then
			continue
		end

		local structureId = identity.StructureId
		local animationState = world:get(entity, components.AnimationStateComponent)
		local animationLooping = world:get(entity, components.AnimationLoopingComponent)
		local targetEnemyId = world:get(entity, components.TargetEnemyIdComponent)

		local nextState = table.freeze({
			StructureId = structureId,
			StructureType = identity.StructureType,
			CurrentHealth = health.Current or 0,
			MaxHealth = health.Max or 0,
			AnimationState = if type(animationState) == "string" then animationState else nil,
			IsAnimationLooping = if type(animationLooping) == "boolean" then animationLooping else nil,
			TargetEnemyId = if type(targetEnemyId) == "string" and targetEnemyId ~= "" then targetEnemyId else nil,
			IsActive = world:has(entity, components.ActiveTag),
		})

		nextStateById[structureId] = nextState

		local previousState = previousStateById[structureId]
		if previousState == nil
			or previousState.StructureType ~= nextState.StructureType
			or previousState.CurrentHealth ~= nextState.CurrentHealth
			or previousState.MaxHealth ~= nextState.MaxHealth
			or previousState.AnimationState ~= nextState.AnimationState
			or previousState.IsAnimationLooping ~= nextState.IsAnimationLooping
			or previousState.TargetEnemyId ~= nextState.TargetEnemyId
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

return StructureReplicationClient
