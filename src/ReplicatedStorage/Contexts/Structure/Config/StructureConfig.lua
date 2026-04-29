--!strict

--[=[
	@class StructureConfig
	Defines shared structure metadata and aliases used by placement and combat.
	@server
	@client
]=]
local StructureConfig = {}

--[=[
	@prop STRUCTURES { [string]: { DisplayName: string, MaxHealth: number, AttackRange: number, AttackDamage: number, AttackCooldown: number, AimRig: any? } }
	@within StructureConfig
	Frozen structure definitions keyed by canonical structure type.
]=]
StructureConfig.STRUCTURES = table.freeze({
	SentryTurret = table.freeze({
		DisplayName = "Sentry Turret",
		MaxHealth = 100,
		AttackRange = 30,
		AttackDamage = 15,
		AttackCooldown = 1.2,
		AimRig = table.freeze({
			Strategy = "IKControl",
			ChainRootPath = "Neck",
			EndEffectorPath = "Body",
			SmoothTime = 0.15,
			Weight = 1,
			Priority = 1,
			ReturnToNeutralWhenNoTarget = true,
		}),
	}),
})

--[=[
	@prop TYPE_ALIASES { [string]: string }
	@within StructureConfig
	Frozen aliases that normalize legacy placement keys to canonical structure types.
]=]
StructureConfig.TYPE_ALIASES = table.freeze({
	SentryTurret = "SentryTurret",
	turret = "SentryTurret",
})

return table.freeze(StructureConfig)
