--!strict

--[=[
	@class StructureTypes
	Defines shared structure entity, component, and attack payload shapes.
	@server
	@client
]=]
local StructureTypes = {}

--[=[
	@type StructureType "SentryTurret" | "Extractor" | "StasisField" | "ArcPylon" | "BulwarkProjector" | "RelayBeacon"
	@within StructureTypes
	Canonical structure type identifier.
]=]
export type StructureType =
	"SentryTurret"
	| "Extractor"
	| "StasisField"
	| "ArcPylon"
	| "BulwarkProjector"
	| "RelayBeacon"

--[=[
	@type StructureId string
	@within StructureTypes
	Stable identifier for a placed structure instance.
]=]
export type StructureId = string

export type ConstructionState = "UnderConstruction" | "Completed"

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

export type TConstructionProgressComponent = {
	CurrentWork: number,
	RequiredWork: number,
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

export type TModelRefComponent = {
	Model: Model,
}

export type TTransformComponent = {
	CFrame: CFrame,
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
	OwnerUserId: number,
}

--[=[
	@interface TStructureConfig
	@within StructureTypes
	.DisplayName string -- Player-facing structure name used by placement and combat UI.
	.MaxHealth number -- Maximum hit points for the structure.
	.BuildWorkRequired number -- Total construction work required before the structure becomes operational.
	.RuntimeProfileId "Attack" | "Extract" | "Passive" | "Stasis" -- Runtime profile that determines the behavior tree.
	.AttackRange number? -- Optional attack range in studs.
	.AttackDamage number? -- Optional attack damage.
	.AttackCooldown number? -- Optional seconds between attacks.
	.StasisRadius number? -- Optional aura radius used by stasis structures.
	.MoveSpeedMultiplier number? -- Optional enemy move-speed multiplier applied by stasis structures.
	.AimRig any? -- Optional aim-rig configuration for combat structures.
]=]
export type TStructureConfig = {
	DisplayName: string,
	MaxHealth: number,
	BuildWorkRequired: number,
	RuntimeProfileId: "Attack" | "Extract" | "Passive" | "Stasis",
	AttackRange: number?,
	AttackDamage: number?,
	AttackCooldown: number?,
	StasisRadius: number?,
	MoveSpeedMultiplier: number?,
	AimRig: any?,
}

--[=[
	@interface ResolvedStructureRecord
	@within StructureTypes
	.structureType StructureType -- Canonical structure type after alias resolution.
	.instanceId number -- Runtime instance identifier from placement.
	.worldPos Vector3 -- Authoritative world position for the structure.
]=]
export type ResolvedStructureRecord = {
	StructureType: StructureType,
	InstanceId: number,
	WorldPos: Vector3,
	RotationQuarterTurns: number,
	OwnerUserId: number,
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

export type TConstructionContributionResult = {
	Completed: boolean,
	Percent: number,
	JustCompleted: boolean,
}

return table.freeze(StructureTypes)
