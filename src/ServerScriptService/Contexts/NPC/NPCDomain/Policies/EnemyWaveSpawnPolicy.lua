--!strict

--[=[
	@class EnemyWaveSpawnPolicy
	Domain policy validating enemy wave spawn parameters against config and candidate state.
	@server
]=]

--[[
	EnemyWaveSpawnPolicy — Domain Policy

	Answers: are these params valid for spawning an enemy wave?

	RESPONSIBILITIES:
	  1. Build a TEnemyWaveSpawnCandidate from the passed params + WaveConfig + EnemyConfig
	  2. Evaluate the CanSpawnEnemyWave spec against the candidate
	  3. Return Ok(nil) on success (no additional state needed by the command)

	All checks are pure config lookups:
	  ZoneValid/WaveValid guard EnemyTypesValid (via And composition) so config access
	  is always safe. EnemyTypesValid is pre-computed in one pass over the wave data.

	RESULT:
	  Ok(nil)   — params are valid for spawning the wave
	  Err(...)  — invalid userId, unknown zone, unknown wave, no spawn points, or invalid enemy type

	USAGE:
	  -- Inside a Catch boundary (Application command):
	  Try(self._enemyWaveSpawnPolicy:Check(userId, waveNumber, zoneId, spawnPoints))
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Result = require(ReplicatedStorage.Utilities.Result)
local Ok, Try = Result.Ok, Result.Try

local EnemyConfig = require(ReplicatedStorage.Contexts.Quest.Config.EnemyConfig)
local WaveConfig = require(ReplicatedStorage.Contexts.NPC.Config.WaveConfig)
local NPCSpecs = require(script.Parent.Parent.Specs.NPCSpecs)

local EnemyWaveSpawnPolicy = {}
EnemyWaveSpawnPolicy.__index = EnemyWaveSpawnPolicy

export type TEnemyWaveSpawnPolicy = typeof(setmetatable({}, EnemyWaveSpawnPolicy))

function EnemyWaveSpawnPolicy.new(): TEnemyWaveSpawnPolicy
	return setmetatable({}, EnemyWaveSpawnPolicy)
end

--[=[
	Validate enemy wave spawn parameters.
	@within EnemyWaveSpawnPolicy
	@param userId number -- Player ID that owns this enemy wave
	@param waveNumber number -- Wave index to spawn
	@param zoneId string -- Zone ID for wave lookup
	@param spawnPoints { any } -- Candidate spawn locations
	@return Result.Result<nil> -- Ok if valid, error codes if any check fails
]=]
function EnemyWaveSpawnPolicy:Check(
	userId: number,
	waveNumber: number,
	zoneId: string,
	spawnPoints: { any }
): Result.Result<nil>
	-- Load zone and wave data from config (nil if not found)
	local zoneData = WaveConfig[zoneId]
	local waveData = zoneData and zoneData[waveNumber]

	-- Validate all enemy types in the wave exist in EnemyConfig (pre-computed in one pass)
	-- Safe because waveData nil means this loop never runs (gated by WaveValid:And spec)
	local enemyTypesValid = true
	if waveData then
		for _, group in ipairs(waveData) do
			if not EnemyConfig[group.EnemyType] then
				enemyTypesValid = false
				break
			end
		end
	end

	-- Build candidate for spec evaluation
	local candidate: NPCSpecs.TEnemyWaveSpawnCandidate = {
		UserIdValid         = userId ~= nil and userId > 0,
		ZoneValid           = zoneData ~= nil,
		-- WaveValid: pass if zone unknown (spec short-circuits ZoneValid:And first), else check wave exists
		WaveValid           = zoneData == nil or waveData ~= nil,
		SpawnPointsProvided = spawnPoints ~= nil and #spawnPoints > 0,
		EnemyTypesValid     = enemyTypesValid,
	}

	-- Evaluate all checks via spec composition
	Try(NPCSpecs.CanSpawnEnemyWave:IsSatisfiedBy(candidate))

	return Ok(nil)
end

return EnemyWaveSpawnPolicy
