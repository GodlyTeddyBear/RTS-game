--!strict

--[=[
	@class StructureTypes
	Defines shared structure entity, component, and attack payload shapes.
	@server
	@client
]=]
local StructureTypes = {}

--[=[
	@type StructureType "SentryTurret"
	@within StructureTypes
	Canonical structure type identifier.
]=]
export type StructureType = "SentryTurret"

--[=[
	@type StructureId string
	@within StructureTypes
	Stable identifier for a placed structure instance.
]=]
export type StructureId = string

--[=[
	@interface TAttackStatsComponent
	@within StructureTypes
	.AttackRange number -- Maximum targeting range in studs.
	.AttackDamage number -- Damage dealt per attack.
	.AttackCooldown number -- Seconds between attacks once a target is locked.
]=]
export type TAttackStatsComponent = {
	AttackRange: number,
	AttackDamage: number,
	AttackCooldown: number,
}

--[=[
	@interface TAttackCooldownComponent
	@within StructureTypes
	.Elapsed number -- Time accumulated since the last shot.
]=]
export type TAttackCooldownComponent = {
	Elapsed: number,
}

--[=[
	@interface THealthComponent
	@within StructureTypes
	.Current number -- Current structure hit points.
	.Max number -- Maximum structure hit points.
]=]
export type THealthComponent = {
	Current: number,
	Max: number,
}

--[=[
	@interface TTargetComponent
	@within StructureTypes
	.Entity any? -- Current target entity or `nil` when idle.
]=]
export type TTargetComponent = {
	Entity: any?,
}

--[=[
	@interface TInstanceRefComponent
	@within StructureTypes
	.InstanceId number -- Runtime instance identifier from PlacementContext.
	.WorldPos Vector3 -- World position used for targeting and range checks.
]=]
export type TInstanceRefComponent = {
	InstanceId: number,
	WorldPos: Vector3,
}

--[=[
	@interface TIdentityComponent
	@within StructureTypes
	.StructureId StructureId -- Stable structure identifier.
	.StructureType StructureType -- Canonical structure type identifier.
]=]
export type TIdentityComponent = {
	StructureId: StructureId,
	StructureType: StructureType,
}

--[=[
	@interface ResolvedStructureRecord
	@within StructureTypes
	.structureType StructureType -- Canonical structure type after alias resolution.
	.instanceId number -- Runtime instance identifier from placement.
	.worldPos Vector3 -- Authoritative world position for the structure.
]=]
export type ResolvedStructureRecord = {
	structureType: StructureType,
	instanceId: number,
	worldPos: Vector3,
}

--[=[
	@interface StructureAttackPayload
	@within StructureTypes
	.structureEntity number -- ECS entity that fired the attack.
	.targetEntity number -- ECS entity that was targeted.
	.damage number -- Damage value that combat should apply.
	.structureType StructureType -- Canonical structure type of the attacker.
]=]
export type StructureAttackPayload = {
	structureEntity: number,
	targetEntity: number,
	damage: number,
	structureType: StructureType,
}

return table.freeze(StructureTypes)
