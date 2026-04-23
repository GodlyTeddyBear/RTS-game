--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WaveTypes = require(ReplicatedStorage.Contexts.Wave.Types.WaveTypes)
local BaseECSEntityFactory = require(ReplicatedStorage.Utilities.BaseECSEntityFactory)

type WaveRuntimeState = WaveTypes.WaveRuntimeState

--[=[
	@class WaveEntityFactory
	Owns wave runtime state in the WaveContext ECS world.
	@server
]=]
local WaveEntityFactory = {}
WaveEntityFactory.__index = WaveEntityFactory
setmetatable(WaveEntityFactory, { __index = BaseECSEntityFactory })

local function _cloneState(state: WaveRuntimeState): WaveRuntimeState
	return {
		isWaveActive = state.isWaveActive,
		currentWaveNumber = state.currentWaveNumber,
		pendingSpawnCount = state.pendingSpawnCount,
		activeEnemyCount = state.activeEnemyCount,
	}
end

local function _defaultState(): WaveRuntimeState
	return {
		isWaveActive = false,
		currentWaveNumber = 0,
		pendingSpawnCount = 0,
		activeEnemyCount = 0,
	}
end

--[=[
	Creates a new wave entity factory wrapper.
	@within WaveEntityFactory
	@return WaveEntityFactory -- The new factory instance.
]=]
function WaveEntityFactory.new()
	local self = setmetatable(BaseECSEntityFactory.new("Wave"), WaveEntityFactory)
	self._componentRegistry = nil
	self._sessionEntity = nil :: number?
	return self
end

--[=[
	Caches the world and component ids for later runtime-state operations.
	@within WaveEntityFactory
	@param registry any -- The dependency registry for this context.
	@param name string -- The registered module name.
]=]
function WaveEntityFactory:_GetComponentRegistryName(): string
	return "WaveComponentRegistry"
end

function WaveEntityFactory:_OnInit(registry: any, _name: string, _componentRegistry: any)
	self._componentRegistry = registry:Get("WaveComponentRegistry")
	self:_EnsureSessionEntity()
end

function WaveEntityFactory:_GetComponents()
	self:RequireReady()

	local components = self._components
	if components ~= nil then
		return components
	end

	components = self._componentRegistry:GetComponents()
	if components ~= nil then
		self._components = components
	end

	return components
end

function WaveEntityFactory:_EnsureSessionEntity(): number
	self:RequireReady()
	local components = self:_GetComponents()
	assert(components ~= nil, "Wave components are not initialized")

	local sessionEntity = self._sessionEntity
	if sessionEntity ~= nil and self:_Exists(sessionEntity) then
		return sessionEntity
	end

	local entity = self:_CreateEntity()
	self:_Set(entity, components.RuntimeStateComponent, _defaultState())
	self:_Add(entity, components.SessionTag)
	self._sessionEntity = entity
	return entity
end

--[=[
	Returns a defensive copy of the current runtime state.
	@within WaveEntityFactory
	@return WaveRuntimeState -- The active wave snapshot.
]=]
function WaveEntityFactory:GetStateReadOnly(): WaveRuntimeState
	local components = self:_GetComponents()
	assert(components ~= nil, "Wave components are not initialized")

	local entity = self:_EnsureSessionEntity()
	local currentState = self:_Get(entity, components.RuntimeStateComponent)
	if currentState == nil then
		currentState = _defaultState()
		self:_Set(entity, components.RuntimeStateComponent, currentState)
	end

	return _cloneState(currentState :: WaveRuntimeState)
end

--[=[
	Replaces the current runtime state with a cloned snapshot.
	@within WaveEntityFactory
	@param nextState WaveRuntimeState -- The new authoritative snapshot.
]=]
function WaveEntityFactory:SetState(nextState: WaveRuntimeState)
	local components = self:_GetComponents()
	assert(components ~= nil, "Wave components are not initialized")

	local entity = self:_EnsureSessionEntity()
	self:_Set(entity, components.RuntimeStateComponent, _cloneState(nextState))
end

--[=[
	Resets the runtime state to the inactive default snapshot.
	@within WaveEntityFactory
]=]
function WaveEntityFactory:Reset()
	self:SetState(_defaultState())
end

return WaveEntityFactory
