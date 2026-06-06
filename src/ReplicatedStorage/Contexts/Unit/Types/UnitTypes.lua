--!strict

local EntityDefinitionTypes = require(script.Parent.Parent.Parent.Entity.Types.EntityDefinitionTypes)

--[=[
	@class UnitTypes
	Shared unit type contracts used by server unit systems.
	@server
	@client
]=]
local UnitTypes = {}

export type UnitDefinitionId = string
export type UnitFaction = "Player" | "Enemy"
export type UnitOwnerKind = "Player" | "PlayerBase" | "EnemyBase"
export type UnitRole = "Combat" | "Builder"
export type UnitMovementMode = "Any" | "Boids" | "Path" | "Direct"

export type UnitDefinition = {
	DefinitionId: UnitDefinitionId,
	Role: UnitRole,
	DisplayName: string,
	Health: EntityDefinitionTypes.HealthDefinition,
	AI: EntityDefinitionTypes.AIDefinition,
	Movement: EntityDefinitionTypes.MovementDefinition,
	Capabilities: {
		Build: EntityDefinitionTypes.BuildCapability?,
	},
	Limits: {
		MaxConcurrentPerOwner: number,
	},
}

export type SpawnUnitRequest = {
	UnitId: UnitDefinitionId,
	Faction: UnitFaction,
	OwnerKind: UnitOwnerKind,
	OwnerId: string,
	SpawnCFrame: CFrame,
	Lifetime: number?,
}

export type SpawnUnitResult = {
	Entity: number,
	UnitId: UnitDefinitionId,
}

export type IssueMoveOrderRequest = {
	UnitGuids: { string },
	Destination: Vector3,
}

export type IdentityComponent = {
	UnitGuid: string,
	UnitId: UnitDefinitionId,
}

export type OwnershipComponent = {
	Faction: UnitFaction,
	OwnerKind: UnitOwnerKind,
	OwnerId: string,
}

export type TransformComponent = {
	CFrame: CFrame,
}

export type HealthComponent = {
	Current: number,
	Max: number,
}

export type MoveSpeedComponent = {
	Value: number,
}

export type AnimationStateComponent = string
export type AnimationLoopingComponent = boolean
export type LockOnComponent = {
	Attachment0: Attachment?,
	Attachment1: Attachment?,
	Constraint: AlignOrientation?,
}

export type RoleComponent = {
	Role: UnitRole,
	DisplayName: string,
	UnitId: UnitDefinitionId,
	MovementMode: UnitMovementMode,
	BuildWorkPerSecond: number?,
	BuildRange: number?,
}

export type BuilderAssignmentComponent = {
	TargetStructureEntity: number?,
}

export type PathStateComponent = {
	GoalPosition: Vector3?,
	RequestedGoalPosition: Vector3?,
	GoalRevision: number,
	FailedGoalRevision: number?,
	IsMoving: boolean,
}

export type LifetimeComponent = {
	SpawnedAt: number,
	ExpiresAt: number,
}

return table.freeze(UnitTypes)
