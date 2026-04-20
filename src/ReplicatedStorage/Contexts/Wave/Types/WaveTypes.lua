--!strict

--[=[
	@class WaveTypes
	Defines shared wave composition and runtime state types.
	@server
	@client
]=]
local WaveTypes = {}

--[=[
	@interface SpawnGroup
	@within WaveTypes
	.role string -- Enemy role for the group.
	.count number -- Number of enemies in the group.
	.groupDelay number -- Delay before the group begins spawning.
]=]
export type SpawnGroup = {
	role: string,
	count: number,
	groupDelay: number,
}

--[=[
	@type WaveComposition { SpawnGroup }
	@within WaveTypes
	Ordered spawn groups for a wave.
]=]
export type WaveComposition = { SpawnGroup }

--[=[
	@interface EndlessRoleThreshold
	@within WaveTypes
	.role string -- Enemy role appended when the endless threshold is reached.
	.count number -- Number of enemies added for the role.
]=]
export type EndlessRoleThreshold = {
	role: string,
	count: number,
}

--[=[
	@interface WaveRuntimeState
	@within WaveTypes
	.isWaveActive boolean -- Whether the current wave session is active.
	.currentWaveNumber number -- The active wave number.
	.pendingSpawnCount number -- Spawns scheduled but not yet activated.
	.activeEnemyCount number -- Enemies currently alive for the wave.
]=]
export type WaveRuntimeState = {
	isWaveActive: boolean,
	currentWaveNumber: number,
	pendingSpawnCount: number,
	activeEnemyCount: number,
}

return table.freeze(WaveTypes)
