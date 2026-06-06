--!strict

local EntityDefinitionTypes = {}

export type MovementMode = "Path" | "Boids" | "Any" | "Direct"

export type HealthDefinition = {
	Max: number,
}

export type AIDefinition = {
	ProfileId: string,
	TickInterval: number?,
}

export type MovementDefinition = {
	Mode: MovementMode,
	Speed: number,
}

export type AttackCapability = {
	Damage: number,
	Range: number,
	Cooldown: number,
	TargetPreference: string?,
}

export type BuildCapability = {
	WorkPerSecond: number,
	Range: number,
}

export type ConstructionCapability = {
	RequiredWork: number,
}

export type StatusAuraCapability = {
	Radius: number,
	MoveSpeedMultiplier: number,
}

export type EntityCapabilities = {
	Attack: AttackCapability?,
	Build: BuildCapability?,
	Construction: ConstructionCapability?,
	StatusAura: StatusAuraCapability?,
	Aim: any?,
}

export type EntityLimits = {
	MaxConcurrentPerOwner: number?,
}

export type EntityDefinition = {
	DefinitionId: string,
	DisplayName: string,
	Health: HealthDefinition?,
	AI: AIDefinition?,
	Movement: MovementDefinition?,
	Capabilities: EntityCapabilities?,
	Limits: EntityLimits?,
}

return table.freeze(EntityDefinitionTypes)
