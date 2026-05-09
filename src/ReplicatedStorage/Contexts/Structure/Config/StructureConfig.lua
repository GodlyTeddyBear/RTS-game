--!strict

--[=[
	@class StructureConfig
	Defines shared structure metadata and aliases used by placement and combat.
	@server
	@client
]=]
local StructureConfig = {}

--[=[
	@prop STRUCTURES { [string]: { DisplayName: string, MaxHealth: number, RuntimeProfileId: string, AttackRange: number?, AttackDamage: number?, AttackCooldown: number?, AimRig: any? } }
	@within StructureConfig
	Frozen structure definitions keyed by canonical structure type.
]=]
StructureConfig.STRUCTURES = table.freeze({
	SentryTurret = table.freeze({
		DisplayName = "Sentry Turret",
		MaxHealth = 100,
		RuntimeProfileId = "Attack",
		AttackRange = 90,
		AttackDamage = 15,
		AttackCooldown = 1.2,
		AimRig = table.freeze({
			Strategy = "IKControl",
			ChainRootPath = "Neck",
			EndEffectorPath = "Body",
			SmoothTime = 0.15,
			Weight = 1,
			Priority = 1,
			-- Keep last tracked orientation until a new target is acquired.
			ReturnToNeutralWhenNoTarget = false,
		}),
	}),
	Extractor = table.freeze({
		DisplayName = "Extractor",
		MaxHealth = 140,
		RuntimeProfileId = "Extract",
	}),
	StasisField = table.freeze({
		DisplayName = "Stasis Field",
		MaxHealth = 140,
		RuntimeProfileId = "Stasis",
		-- Aura radius in studs used to detect enemies inside the field.
		StasisRadius = 18,
		-- Multiplier applied to enemy base move speed while they remain inside the field.
		MoveSpeedMultiplier = 0.5,
	}),
	ArcPylon = table.freeze({
		DisplayName = "Arc Pylon",
		MaxHealth = 140,
		RuntimeProfileId = "Passive",
	}),
	BulwarkProjector = table.freeze({
		DisplayName = "Bulwark Projector",
		MaxHealth = 140,
		RuntimeProfileId = "Passive",
	}),
	RelayBeacon = table.freeze({
		DisplayName = "Relay Beacon",
		MaxHealth = 140,
		RuntimeProfileId = "Passive",
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
	Extractor = "Extractor",
	StasisField = "StasisField",
	ArcPylon = "ArcPylon",
	["Arc Pylon"] = "ArcPylon",
	BulwarkProjector = "BulwarkProjector",
	["Bulwark Projector"] = "BulwarkProjector",
	RelayBeacon = "RelayBeacon",
	["Relay Beacon"] = "RelayBeacon",
})

return table.freeze(StructureConfig)
