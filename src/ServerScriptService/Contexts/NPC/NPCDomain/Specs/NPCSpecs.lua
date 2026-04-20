--!strict

--[=[
	@class NPCSpecs
	Composable eligibility rules for NPC spawn operations (adventurer parties and enemy waves).

	Exported specs combine individual checks via `And()` composition to form compound eligibility rules.
	These are evaluated against candidate objects during spawn validation.
	@server
]=]

--[[
	NPCSpecs — Composable eligibility rules for NPC spawn operations.

	CANDIDATE TYPES:
	  TAdventurerSpawnCandidate — state needed to evaluate adventurer party spawn eligibility
	  TEnemyWaveSpawnCandidate  — state needed to evaluate enemy wave spawn eligibility

	INDIVIDUAL SPECS (shared):
	  UserIdValid       — userId is a positive number
	  SpawnPointsProvided — spawn point array is non-empty

	INDIVIDUAL SPECS (adventurer):
	  AdventurersProvided  — adventurer map is non-empty
	  AdventurerDataValid  — all adventurers have required stat fields (Type, BaseHP, BaseATK, BaseDEF)

	INDIVIDUAL SPECS (enemy wave):
	  ZoneValid         — zoneId exists in WaveConfig
	  WaveValid         — waveNumber exists for the given zone
	  EnemyTypesValid   — all enemy types in the wave exist in EnemyConfig

	COMPOSED SPECS:
	  CanSpawnAdventurerParty — UserIdValid:And(All({ AdventurersProvided, SpawnPointsProvided, AdventurerDataValid }))
	  CanSpawnEnemyWave       — UserIdValid:And(ZoneValid:And(All({ WaveValid, SpawnPointsProvided, EnemyTypesValid })))

	USAGE:
	  Try(NPCSpecs.CanSpawnAdventurerParty:IsSatisfiedBy(candidate))
	  Try(NPCSpecs.CanSpawnEnemyWave:IsSatisfiedBy(candidate))
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Spec = require(ReplicatedStorage.Utilities.Specification)
local Errors = require(script.Parent.Parent.Parent.Errors)

-- Candidate types

export type TAdventurerSpawnCandidate = {
	UserIdValid: boolean,
	AdventurersProvided: boolean,
	SpawnPointsProvided: boolean,
	AdventurerDataValid: boolean,
}

export type TEnemyWaveSpawnCandidate = {
	UserIdValid: boolean,
	ZoneValid: boolean,
	WaveValid: boolean,
	SpawnPointsProvided: boolean,
	EnemyTypesValid: boolean,
}

-- Individual specs (shared fields — work for both candidate types)

local UserIdValid = Spec.new("InvalidUserId", Errors.INVALID_USER_ID,
	function(ctx: TAdventurerSpawnCandidate)
		return ctx.UserIdValid
	end
)

local SpawnPointsProvided = Spec.new("NoSpawnPoints", Errors.NO_SPAWN_POINTS,
	function(ctx: TAdventurerSpawnCandidate)
		return ctx.SpawnPointsProvided
	end
)

-- Individual specs (adventurer spawn)

local AdventurersProvided = Spec.new("NoAdventurers", Errors.NO_ADVENTURERS,
	function(ctx: TAdventurerSpawnCandidate)
		return ctx.AdventurersProvided
	end
)

local AdventurerDataValid = Spec.new("InvalidAdventurerData", Errors.INVALID_ADVENTURER_DATA,
	function(ctx: TAdventurerSpawnCandidate)
		return ctx.AdventurerDataValid
	end
)

-- Individual specs (enemy wave spawn)

local ZoneValid = Spec.new("InvalidZoneId", Errors.INVALID_ZONE_ID,
	function(ctx: TEnemyWaveSpawnCandidate)
		return ctx.ZoneValid
	end
)

local WaveValid = Spec.new("InvalidWaveNumber", Errors.INVALID_WAVE_NUMBER,
	function(ctx: TEnemyWaveSpawnCandidate)
		return ctx.WaveValid
	end
)

local EnemyTypesValid = Spec.new("InvalidEnemyType", Errors.INVALID_ENEMY_TYPE,
	function(ctx: TEnemyWaveSpawnCandidate)
		return ctx.EnemyTypesValid
	end
)

-- Composed specs

return table.freeze({
	CanSpawnAdventurerParty = UserIdValid:And(Spec.All({ AdventurersProvided, SpawnPointsProvided, AdventurerDataValid })),
	CanSpawnEnemyWave       = UserIdValid:And(ZoneValid:And(Spec.All({ WaveValid, SpawnPointsProvided, EnemyTypesValid }))),
})
