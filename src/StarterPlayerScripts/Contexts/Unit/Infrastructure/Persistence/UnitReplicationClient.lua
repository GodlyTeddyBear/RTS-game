--!strict

--[=[
    @class UnitReplicationClient
    Maintains the client-side replicated unit ECS surface and exposes per-unit state snapshots to the animation layer.

    Owns the transport hookup, replicated-state index, and change notifications for unit replication on the client.
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

--[=[
    @interface TUnitReplicatedState
    @within UnitReplicationClient
    .UnitGuid string -- Stable GUID for the replicated unit.
    .UnitId string -- Unit definition identifier.
    .CurrentHealth number -- Current replicated health value.
    .MaxHealth number -- Maximum replicated health value.
    .AnimationState string? -- Current animation state name, if one is set.
    .IsAnimationLooping boolean? -- Whether the current animation should loop, if known.
    .IsActive boolean -- Whether the active-tag is currently present.
]=]
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

-- Names a replicated entity or component so the ECS surface stays readable in debugging tools.
local function _NameEntity(world: any, entity: any, name: string)
	world:set(entity, JECS.Name, name)
end

-- Creates the client replication wrapper with the Unit namespace and an empty state index.
function UnitReplicationClient.new()
	local self = setmetatable(BaseECSReplicationClient.new("Unit"), UnitReplicationClient)
	self.StateChanged = GoodSignal.new()
	self._unitContext = nil
	self._unitStateByGuid = {}
	return self
end

-- Builds the ECS component set used by the unit replication surface.
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

-- Returns the shared ECS schema exposed by the client replication surface.
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

-- Rebuilds the GUID index after the replicated surface is wired up.
function UnitReplicationClient:_RegisterReplicatedSurface()
	self:_RebuildUnitStateIndex()
end

-- Rebuilds the snapshot index after bootstrap payloads are processed so listeners see the latest unit state.
function UnitReplicationClient:HandleBootstrap(payload: TBootstrapPayload): boolean
	local handled = BaseECSReplicationClient.HandleBootstrap(self, payload)
	self:_RebuildUnitStateIndex()
	return handled
end

-- Rebuilds the snapshot index after reliable packets are applied.
function UnitReplicationClient:HandleReliable(payload: TReplicationPacketPayload)
	BaseECSReplicationClient.HandleReliable(self, payload)
	self:_RebuildUnitStateIndex()
end

-- Rebuilds the snapshot index after unreliable packets are applied.
function UnitReplicationClient:HandleUnreliable(payload: TReplicationPacketPayload)
	BaseECSReplicationClient.HandleUnreliable(self, payload)
	self:_RebuildUnitStateIndex()
end

-- Rebuilds the snapshot index after entity-level packets are applied.
function UnitReplicationClient:HandleEntity(payload: TReplicationPacketPayload)
	BaseECSReplicationClient.HandleEntity(self, payload)
	self:_RebuildUnitStateIndex()
end

-- Connects the unit-context transport events to the replication client.
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

-- Requests replication from the unit context once transport setup is complete.
function UnitReplicationClient:_OnStart()
	assert(self._unitContext ~= nil, "UnitReplicationClient: missing UnitContext")
	self._unitContext:RequestUnitReplication()
end

-- Acknowledges bootstrap completion so the server knows the client is ready for steady-state updates.
function UnitReplicationClient:_OnBootstrapCompleted()
	assert(self._unitContext ~= nil, "UnitReplicationClient: missing UnitContext")
	self._unitContext:AcknowledgeUnitReplicationBootstrap()
end

-- Returns the latest replicated state for the requested unit GUID.
function UnitReplicationClient:GetUnitState(unitGuid: string): TUnitReplicatedState?
	return self._unitStateByGuid[unitGuid]
end

-- Subscribes listeners to unit state changes so animation can react to the replication stream.
function UnitReplicationClient:ObserveUnitStateChanged(callback: (unitGuid: string) -> ())
	return self.StateChanged:Connect(callback)
end

-- Disconnects transport listeners and clears the cached unit state index.
function UnitReplicationClient:Destroy()
	if self.StateChanged ~= nil then
		self.StateChanged:DisconnectAll()
	end

	BaseECSReplicationClient.Destroy(self)
	self._unitContext = nil
	table.clear(self._unitStateByGuid)
end

-- Rebuilds the cached GUID index and fires change notifications for any unit whose snapshot changed.
function UnitReplicationClient:_RebuildUnitStateIndex()
	local world = self:GetWorldOrThrow()
	local components = self:GetComponentsOrThrow()
	local nextStateByGuid = {}
	local changedUnitGuids = {}
	local previousStateByGuid = self._unitStateByGuid

	-- Build the next state index from the current ECS query result.
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

	-- Mark removals as changes too so observers can drop stale references immediately.
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
