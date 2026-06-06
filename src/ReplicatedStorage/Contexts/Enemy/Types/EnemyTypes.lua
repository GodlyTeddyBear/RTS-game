--!strict

local EntityDefinitionTypes = require(script.Parent.Parent.Parent.Entity.Types.EntityDefinitionTypes)

--[=[
	@class EnemyTypes
	Defines shared enemy entity and component shapes.
	@server
	@client
]=]
local EnemyTypes = {}

export type EnemyRole = "Swarm" | "Tank"
export type EnemyMovementMode = "Path" | "Boids" | "Any" | "Direct"
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
	WaveNumber: number,
	MoveSpeed: number,
	Damage: number,
	AttackRange: number,
	AttackCooldown: number,
	TargetPreference: EnemyTargetPreference,
	MovementMode: EnemyMovementMode,
}

export type MoveSpeedComponent = {
	Value: number,
}

export type PathStateComponent = {
	GoalPosition: Vector3?,
	IsMoving: boolean,
}

export type ModelRefComponent = {
	Model: Model,
}

export type EnemyRoleConfig = {
	DefinitionId: EnemyRole,
	DisplayName: string,
	Health: EntityDefinitionTypes.HealthDefinition,
	AI: EntityDefinitionTypes.AIDefinition,
	Movement: {
		Mode: EnemyMovementMode,
		Speed: number,
	},
	Capabilities: {
		Attack: {
			Damage: number,
			Range: number,
			Cooldown: number,
			TargetPreference: EnemyTargetPreference,
		},
	},
}

export type EnemyConfig = {
	Definitions: { [EnemyRole]: EnemyRoleConfig },
}

export type PositionComponent = TransformComponent

export type AliveTag = boolean

export type DirtyTag = boolean

export type GoalReachedTag = boolean

return table.freeze(EnemyTypes)
