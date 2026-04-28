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

export type TransformComponent = {
	CFrame: CFrame,
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
	Model: Model,
}

export type PositionComponent = TransformComponent

export type AliveTag = boolean

export type DirtyTag = boolean

export type GoalReachedTag = boolean

return table.freeze(EnemyTypes)
