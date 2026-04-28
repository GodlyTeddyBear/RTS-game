--!strict

--[=[
	@class EnemyTypes
	Defines shared enemy entity and component shapes.
	@server
	@client
]=]
local EnemyTypes = {}

export type EnemyRole = "Swarm" | "Tank"
export type EnemyMovementMode = "Path" | "Boids" | "Any"
export type EnemyTargetPreference = "Goal"

export type EnemyIdentity = {
	EnemyId: string,
	Role: EnemyRole,
	WaveNumber: number,
}

export type HealthComponent = {
	Current: number,
	Max: number,
}

export type TransformComponent = {
	CFrame: CFrame,
}

export type RoleComponent = {
	Role: EnemyRole,
	MoveSpeed: number,
	Damage: number,
	AttackRange: number,
	AttackCooldown: number,
	TargetPreference: EnemyTargetPreference,
}

export type PathStateComponent = {
	GoalPosition: Vector3?,
	IsMoving: boolean,
}

export type ModelRefComponent = {
	Model: Model,
}

export type EnemyRoleConfig = {
	DisplayName: string,
	MaxHp: number,
	Damage: number,
	AttackRange: number,
	AttackCooldown: number,
	MoveSpeed: number,
	TargetPreference: EnemyTargetPreference,
	ModelScale: Vector3,
	ModelColor: Color3,
	MovementMode: EnemyMovementMode,
}

export type EnemyConfig = {
	Roles: { [EnemyRole]: EnemyRoleConfig },
	Phase2AllowedRoles: { [EnemyRole]: boolean },
}

export type PositionComponent = TransformComponent

export type AliveTag = boolean

export type DirtyTag = boolean

export type GoalReachedTag = boolean

return table.freeze(EnemyTypes)
