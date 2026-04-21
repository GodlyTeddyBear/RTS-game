--!strict

--[=[
	@class StructureConfig
	Defines shared structure metadata and aliases used by placement and combat.
	@server
	@client
]=]
local StructureConfig = {}

--[=[
	@prop STRUCTURES { [string]: { DisplayName: string, AttackRange: number, AttackDamage: number, AttackCooldown: number } }
	@within StructureConfig
	Frozen structure definitions keyed by canonical structure type.
]=]
StructureConfig.STRUCTURES = table.freeze({
	SentryTurret = table.freeze({
		DisplayName = "Sentry Turret",
		AttackRange = 18,
		AttackDamage = 15,
		AttackCooldown = 1.2,
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
