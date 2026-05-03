--!strict

--[[
    Module: WaveTypes
    Purpose: Defines shared wave composition and runtime state types used across server and client code.
    Used In System: Imported by Wave context services and shared UI/state consumers.
    Boundaries: Owns type declarations only; does not own behavior, mutation, or transport wiring.
]]

-- [Types]

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
	.Role string -- Enemy role for the group.
	.Count number -- Number of enemies in the group.
	.GroupDelay number -- Delay before the group begins spawning.
]=]
export type SpawnGroup = {
	Role: string,
	Count: number,
	GroupDelay: number,
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
	.Role string -- Enemy role appended when the endless threshold is reached.
	.Count number -- Number of enemies added for the role.
]=]
export type EndlessRoleThreshold = {
	Role: string,
	Count: number,
}

--[=[
	@interface WaveRuntimeState
	@within WaveTypes
	.IsWaveActive boolean -- Whether the current wave session is active.
	.CurrentWaveNumber number -- The active wave number.
	.PendingSpawnCount number -- Spawns scheduled but not yet activated.
	.ActiveEnemyCount number -- Enemies currently alive for the wave.
]=]
export type WaveRuntimeState = {
	IsWaveActive: boolean,
	CurrentWaveNumber: number,
	PendingSpawnCount: number,
	ActiveEnemyCount: number,
}

return table.freeze(WaveTypes)
