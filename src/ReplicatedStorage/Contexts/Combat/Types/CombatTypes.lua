--!strict

--[=[
	@class CombatTypes
	Defines shared combat runtime shapes used by the combat context.
]=]
local CombatTypes = {}

export type CombatSession = {
	isActive: boolean,
	currentWaveNumber: number,
	isEndless: boolean,
}

export type GoalResolution = {
	enemyEntity: number,
	role: string,
	waveNumber: number,
	deathCFrame: CFrame,
	damage: number,
}

return table.freeze(CombatTypes)
