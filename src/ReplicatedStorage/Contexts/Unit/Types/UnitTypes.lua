--!strict

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

export type RoleComponent = {
	Role: UnitRole,
	DisplayName: string,
	MaxHp: number,
}

export type LifetimeComponent = {
	SpawnedAt: number,
	ExpiresAt: number,
}

return table.freeze(UnitTypes)
