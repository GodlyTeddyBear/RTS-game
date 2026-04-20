--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WaveTypes = require(ReplicatedStorage.Contexts.Wave.Types.WaveTypes)

type WaveRuntimeState = WaveTypes.WaveRuntimeState

local DEFAULT_STATE: WaveRuntimeState = table.freeze({
	isWaveActive = false,
	currentWaveNumber = 0,
	pendingSpawnCount = 0,
	activeEnemyCount = 0,
})

--[=[
	@class WaveRuntimeStateService
	Stores the authoritative in-memory wave session state.
	@server
]=]
local WaveRuntimeStateService = {}
WaveRuntimeStateService.__index = WaveRuntimeStateService

local function cloneState(state: WaveRuntimeState): WaveRuntimeState
	return {
		isWaveActive = state.isWaveActive,
		currentWaveNumber = state.currentWaveNumber,
		pendingSpawnCount = state.pendingSpawnCount,
		activeEnemyCount = state.activeEnemyCount,
	}
end

--[=[
	Creates a new runtime state service with the default inactive snapshot.
	@within WaveRuntimeStateService
	@return WaveRuntimeStateService -- The new service instance.
]=]
function WaveRuntimeStateService.new()
	local self = setmetatable({}, WaveRuntimeStateService)
	self._state = cloneState(DEFAULT_STATE)
	return self
end

--[=[
	Initializes the service for registry ownership.
	@within WaveRuntimeStateService
	@param registry any -- The owning registry.
	@param name string -- The registered module name.
]=]
function WaveRuntimeStateService:Init(_registry: any, _name: string)
end

--[=[
	Returns a defensive copy of the current runtime state.
	@within WaveRuntimeStateService
	@return WaveRuntimeState -- The active wave snapshot.
]=]
function WaveRuntimeStateService:GetStateReadOnly(): WaveRuntimeState
	return cloneState(self._state)
end

--[=[
	Replaces the current runtime state with a cloned snapshot.
	@within WaveRuntimeStateService
	@param nextState WaveRuntimeState -- The new authoritative snapshot.
]=]
function WaveRuntimeStateService:SetState(nextState: WaveRuntimeState)
	self._state = cloneState(nextState)
end

--[=[
	Resets the runtime state to the inactive default snapshot.
	@within WaveRuntimeStateService
]=]
function WaveRuntimeStateService:Reset()
	self._state = cloneState(DEFAULT_STATE)
end

return WaveRuntimeStateService
