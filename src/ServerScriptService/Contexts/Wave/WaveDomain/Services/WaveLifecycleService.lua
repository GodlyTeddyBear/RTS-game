--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WaveTypes = require(ReplicatedStorage.Contexts.Wave.Types.WaveTypes)

type WaveRuntimeState = WaveTypes.WaveRuntimeState

--[=[
	@class WaveLifecycleService
	Encodes the pure wave session lifecycle checks and state builders.
	@server
]=]
local WaveLifecycleService = {}
WaveLifecycleService.__index = WaveLifecycleService

--[=[
	Creates a new lifecycle service.
	@within WaveLifecycleService
	@return WaveLifecycleService -- The new service instance.
]=]
function WaveLifecycleService.new()
	return setmetatable({}, WaveLifecycleService)
end

--[=[
	Initializes the service for registry ownership.
	@within WaveLifecycleService
	@param registry any -- The owning registry.
	@param name string -- The registered module name.
]=]
function WaveLifecycleService:Init(_registry: any, _name: string)
end

--[=[
	Builds the inactive runtime state snapshot.
	@within WaveLifecycleService
	@return WaveRuntimeState -- The reset state.
]=]
function WaveLifecycleService:ResetState(): WaveRuntimeState
	return {
		isWaveActive = false,
		currentWaveNumber = 0,
		pendingSpawnCount = 0,
		activeEnemyCount = 0,
	}
end

--[=[
	Builds the active runtime state snapshot for a newly started wave.
	@within WaveLifecycleService
	@param waveNumber number -- The active wave number.
	@param plannedSpawnCount number -- The number of scheduled enemy spawns.
	@return WaveRuntimeState -- The initialized wave state.
]=]
function WaveLifecycleService:StartWaveSession(waveNumber: number, plannedSpawnCount: number): WaveRuntimeState
	return {
		isWaveActive = true,
		currentWaveNumber = waveNumber,
		pendingSpawnCount = plannedSpawnCount,
		activeEnemyCount = 0,
	}
end

--[=[
	Checks whether the wave session is active.
	@within WaveLifecycleService
	@param state WaveRuntimeState -- The current runtime state.
	@return boolean -- Whether the wave is active.
]=]
function WaveLifecycleService:IsWaveActive(state: WaveRuntimeState): boolean
	return state.isWaveActive
end

--[=[
	Checks whether the provided wave number matches the active session.
	@within WaveLifecycleService
	@param state WaveRuntimeState -- The current runtime state.
	@param waveNumber number -- The wave number to compare.
	@return boolean -- Whether the numbers match and the wave is active.
]=]
function WaveLifecycleService:IsCurrentWave(state: WaveRuntimeState, waveNumber: number): boolean
	return state.isWaveActive and state.currentWaveNumber == waveNumber
end

--[=[
	Checks whether all scheduled and active enemies are cleared.
	@within WaveLifecycleService
	@param state WaveRuntimeState -- The current runtime state.
	@return boolean -- Whether the wave can transition to completion.
]=]
function WaveLifecycleService:ShouldCompleteWave(state: WaveRuntimeState): boolean
	return state.isWaveActive and state.pendingSpawnCount <= 0 and state.activeEnemyCount <= 0
end

--[=[
	Marks the wave session as completed without changing the counters.
	@within WaveLifecycleService
	@param state WaveRuntimeState -- The current runtime state.
	@return WaveRuntimeState -- The completed snapshot.
]=]
function WaveLifecycleService:MarkWaveCompleted(state: WaveRuntimeState): WaveRuntimeState
	return {
		isWaveActive = false,
		currentWaveNumber = state.currentWaveNumber,
		pendingSpawnCount = state.pendingSpawnCount,
		activeEnemyCount = state.activeEnemyCount,
	}
end

return WaveLifecycleService
