--!strict

--[=[
	@class UnitTypes
	Shared unit type contracts used by server unit systems.
	@server
	@client
]=]
local UnitTypes = {}
local ReplicatedStorage = game:GetService("ReplicatedStorage")

export type UnitDefinitionId = string
export type UnitFaction = "Player" | "Enemy"
export type UnitOwnerKind = "Player" | "PlayerBase" | "EnemyBase"
export type UnitRole = "Combat" | "Builder"
export type UnitMovementMode = "Any" | "Boids" | "Path"

export type UnitDefinition = {
	UnitId: UnitDefinitionId,
	RuntimeProfileId: string,
	Role: UnitRole,
	DisplayName: string,
	MaxHp: number,
	MoveSpeed: number,
	ModelScale: Vector3,
	ModelColor: Color3,
	MaxConcurrentUnitsPerOwner: number,
	MovementMode: UnitMovementMode,
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
	Hp: number,
	MaxHp: number,
}

export type MoveSpeedComponent = {
	Value: number,
}

export type AnimationStateComponent = string
export type AnimationLoopingComponent = boolean

export type RoleComponent = {
	Role: UnitRole,
	DisplayName: string,
	MaxHp: number,
}

export type PathStateComponent = {
	GoalPosition: Vector3?,
	RequestedGoalPosition: Vector3?,
	IsMoving: boolean,
}

export type LifetimeComponent = {
	SpawnedAt: number,
	ExpiresAt: number,
}

return table.freeze(UnitTypes)
