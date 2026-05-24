--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GoodSignal = require(ReplicatedStorage.Packages.Goodsignal)
require(ReplicatedStorage.Utilities.Replecs)
local JECS = require(ReplicatedStorage.Packages.JECS)
local Knit = require(ReplicatedStorage.Packages.Knit)
local BaseECSReplicationClient = require(ReplicatedStorage.Utilities.BaseECSReplicationClient)
local StashPlus = require(ReplicatedStorage.Utilities.StashPlus)

type TBootstrapPayload = BaseECSReplicationClient.TBootstrapPayload
type TReplicationPacketPayload = BaseECSReplicationClient.TReplicationPacketPayload

export type TUnitReplicatedState = {
	UnitGuid: string,
	UnitId: string,
	CurrentHealth: number,
	MaxHealth: number,
	AnimationState: string?,
	IsAnimationLooping: boolean?,
	IsActive: boolean,
}

local UnitReplicationClient = {}
UnitReplicationClient.__index = UnitReplicationClient
setmetatable(UnitReplicationClient, { __index = BaseECSReplicationClient })

local function _NameEntity(world: any, entity: any, name: string)
	world:set(entity, JECS.Name, name)
end

function UnitReplicationClient.new()
	local self = setmetatable(BaseECSReplicationClient.new("Unit"), UnitReplicationClient)
	self.StateChanged = GoodSignal.new()
	self._unitContext = nil
	self._unitStateByGuid = {}
	return self
end

function UnitReplicationClient:_BuildComponents(world: any, _replecsLibrary: any)
	local identityComponent = world:component()
	_NameEntity(world, identityComponent, "Unit.Identity")

	local healthComponent = world:component()
	_NameEntity(world, healthComponent, "Unit.Health")

	local animationStateComponent = world:component()
	_NameEntity(world, animationStateComponent, "Unit.AnimationState")

	local animationLoopingComponent = world:component()
	_NameEntity(world, animationLoopingComponent, "Unit.AnimationLooping")

	local activeTag = world:entity()
	_NameEntity(world, activeTag, "Unit.ActiveTag")

	return table.freeze({
		IdentityComponent = identityComponent,
		HealthComponent = healthComponent,
		AnimationStateComponent = animationStateComponent,
		AnimationLoopingComponent = animationLoopingComponent,
		ActiveTag = activeTag,
	})
end

function UnitReplicationClient:_GetSharedSchema()
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

function UnitReplicationClient:_RegisterReplicatedSurface()
	self:_RebuildUnitStateIndex()
end

function UnitReplicationClient:HandleBootstrap(payload: TBootstrapPayload): boolean
	local handled = BaseECSReplicationClient.HandleBootstrap(self, payload)
	self:_RebuildUnitStateIndex()
	return handled
end

function UnitReplicationClient:HandleReliable(payload: TReplicationPacketPayload)
	BaseECSReplicationClient.HandleReliable(self, payload)
	self:_RebuildUnitStateIndex()
end

function UnitReplicationClient:HandleUnreliable(payload: TReplicationPacketPayload)
	BaseECSReplicationClient.HandleUnreliable(self, payload)
	self:_RebuildUnitStateIndex()
end

function UnitReplicationClient:HandleEntity(payload: TReplicationPacketPayload)
	BaseECSReplicationClient.HandleEntity(self, payload)
	self:_RebuildUnitStateIndex()
end

function UnitReplicationClient:_ConnectTransport()
	self._unitContext = Knit.GetService("UnitContext")
	local stash = StashPlus.new()

	stash:AddConnection(self._unitContext.UnitBootstrap:Connect(function(payload)
		self:HandleBootstrap(payload)
	end))
	stash:AddConnection(self._unitContext.UnitReliable:Connect(function(payload)
		self:HandleReliable(payload)
	end))
	stash:AddConnection(self._unitContext.UnitUnreliable:Connect(function(payload)
		self:HandleUnreliable(payload)
	end))
	stash:AddConnection(self._unitContext.UnitEntity:Connect(function(payload)
		self:HandleEntity(payload)
	end))

	return stash
end

function UnitReplicationClient:_OnStart()
	assert(self._unitContext ~= nil, "UnitReplicationClient: missing UnitContext")
	self._unitContext:RequestUnitReplication()
end

function UnitReplicationClient:_OnBootstrapCompleted()
	assert(self._unitContext ~= nil, "UnitReplicationClient: missing UnitContext")
	self._unitContext:AcknowledgeUnitReplicationBootstrap()
end

function UnitReplicationClient:GetUnitState(unitGuid: string): TUnitReplicatedState?
	return self._unitStateByGuid[unitGuid]
end

function UnitReplicationClient:ObserveUnitStateChanged(callback: (unitGuid: string) -> ())
	return self.StateChanged:Connect(callback)
end

function UnitReplicationClient:Destroy()
	if self.StateChanged ~= nil then
		self.StateChanged:DisconnectAll()
	end

	BaseECSReplicationClient.Destroy(self)
	self._unitContext = nil
	table.clear(self._unitStateByGuid)
end

function UnitReplicationClient:_RebuildUnitStateIndex()
	local world = self:GetWorldOrThrow()
	local components = self:GetComponentsOrThrow()
	local nextStateByGuid = {}
	local changedUnitGuids = {}
	local previousStateByGuid = self._unitStateByGuid

	for entity, identity, health in world:query(components.IdentityComponent, components.HealthComponent):iter() do
		if type(identity) ~= "table" or type(identity.UnitGuid) ~= "string" or type(identity.UnitId) ~= "string" then
			continue
		end
		if type(health) ~= "table" then
			continue
		end

		local unitGuid = identity.UnitGuid
		local animationState = world:get(entity, components.AnimationStateComponent)
		local animationLooping = world:get(entity, components.AnimationLoopingComponent)
		local nextState = table.freeze({
			UnitGuid = unitGuid,
			UnitId = identity.UnitId,
			CurrentHealth = health.Hp or 0,
			MaxHealth = health.MaxHp or 0,
			AnimationState = if type(animationState) == "string" then animationState else nil,
			IsAnimationLooping = if type(animationLooping) == "boolean" then animationLooping else nil,
			IsActive = world:has(entity, components.ActiveTag),
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

return UnitReplicationClient
