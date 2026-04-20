--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WaveTypes = require(ReplicatedStorage.Contexts.Wave.Types.WaveTypes)

type WaveRuntimeState = WaveTypes.WaveRuntimeState
type WaveComposition = WaveTypes.WaveComposition

--[=[
	@class WaveCountingService
	Calculates the wave spawn and alive counts without side effects.
	@server
]=]
local WaveCountingService = {}
WaveCountingService.__index = WaveCountingService

--[=[
	Creates a new counting service.
	@within WaveCountingService
	@return WaveCountingService -- The new service instance.
]=]
function WaveCountingService.new()
	return setmetatable({}, WaveCountingService)
end

--[=[
	Initializes the service for registry ownership.
	@within WaveCountingService
	@param registry any -- The owning registry.
	@param name string -- The registered module name.
]=]
function WaveCountingService:Init(_registry: any, _name: string)
end

--[=[
	Counts all planned spawns in a wave composition.
	@within WaveCountingService
	@param composition WaveComposition -- The ordered spawn groups.
	@return number -- Total scheduled spawns.
]=]
function WaveCountingService:GetPlannedSpawnCount(composition: WaveComposition): number
	local total = 0
	for _, group in composition do
		total += group.count
	end
	return total
end

--[=[
	Applies the spawn activation step for a newly emitted enemy.
	@within WaveCountingService
	@param state WaveRuntimeState -- The current runtime state.
	@return WaveRuntimeState -- The updated runtime state.
]=]
function WaveCountingService:ApplySpawnActivated(state: WaveRuntimeState): WaveRuntimeState
	return {
		isWaveActive = state.isWaveActive,
		currentWaveNumber = state.currentWaveNumber,
		pendingSpawnCount = math.max(0, state.pendingSpawnCount - 1),
		activeEnemyCount = state.activeEnemyCount + 1,
	}
end

--[=[
	Applies the enemy death step for the active wave session.
	@within WaveCountingService
	@param state WaveRuntimeState -- The current runtime state.
	@return WaveRuntimeState -- The updated runtime state.
]=]
function WaveCountingService:ApplyEnemyDied(state: WaveRuntimeState): WaveRuntimeState
	return {
		isWaveActive = state.isWaveActive,
		currentWaveNumber = state.currentWaveNumber,
		pendingSpawnCount = state.pendingSpawnCount,
		activeEnemyCount = math.max(0, state.activeEnemyCount - 1),
	}
end

return WaveCountingService
