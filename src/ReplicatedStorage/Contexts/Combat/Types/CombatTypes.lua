--!strict

--[=[
	@class CombatTypes
	Defines shared combat runtime shapes used by the combat context.
	@server
	@client
]=]
local CombatTypes = {}

--[=[
	@interface CombatSession
	@within CombatTypes
	Active combat session metadata keyed by user id.
	.WaveNumber number -- Current wave number for the active session.
	.IsEndless boolean -- Whether the current run is endless.
	.IsPaused boolean -- Whether combat updates are paused.
]=]
export type CombatSession = {
	WaveNumber: number,
	IsEndless: boolean,
	IsPaused: boolean,
}

--[=[
	@interface GoalResolution
	@within CombatTypes
	Resolved data describing an enemy that reached the goal.
	.enemyEntity number -- Entity id that reached the goal.
	.role string -- Enemy role used for damage tuning.
	.waveNumber number -- Wave number associated with the enemy.
	.deathCFrame CFrame -- CFrame captured before despawn.
	.damage number -- Commander damage to apply.
]=]
export type GoalResolution = {
	enemyEntity: number,
	role: string,
	waveNumber: number,
	deathCFrame: CFrame,
	damage: number,
}

return table.freeze(CombatTypes)
