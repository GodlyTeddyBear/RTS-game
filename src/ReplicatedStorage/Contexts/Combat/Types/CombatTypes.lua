--!strict

--[=[
	@class CombatTypes
	Defines shared combat runtime shapes used by the combat context.
]=]
local CombatTypes = {}

--[=[
	@type CombatSession
	@within CombatTypes
	Active combat session metadata keyed by user id.
]=]
export type CombatSession = {
	WaveNumber: number,
	IsEndless: boolean,
	IsPaused: boolean,
}

--[=[
	@type GoalResolution
	@within CombatTypes
	Resolved data describing an enemy that reached the goal.
]=]
export type GoalResolution = {
	enemyEntity: number,
	role: string,
	waveNumber: number,
	deathCFrame: CFrame,
	damage: number,
}

return table.freeze(CombatTypes)
