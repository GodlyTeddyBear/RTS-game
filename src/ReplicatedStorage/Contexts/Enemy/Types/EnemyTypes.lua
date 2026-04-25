--!strict

--[=[
	@class EnemyTypes
	Defines shared enemy entity and component shapes.
	@server
	@client
]=]
local EnemyTypes = {}

export type EnemyRole = "swarm" | "tank"

export type EnemyIdentity = {
	enemyId: string,
	role: EnemyRole,
	waveNumber: number,
}

export type HealthComponent = {
	current: number,
	max: number,
}

export type PositionComponent = {
	cframe: CFrame,
}

export type RoleComponent = {
	role: EnemyRole,
	moveSpeed: number,
	damage: number,
	attackRange: number,
	attackCooldown: number,
	targetPreference: string,
}

export type PathStateComponent = {
	goalPosition: Vector3?,
	isMoving: boolean,
}

export type ModelRefComponent = {
	model: Model,
}

export type AliveTag = boolean

export type DirtyTag = boolean

export type GoalReachedTag = boolean

return table.freeze(EnemyTypes)
