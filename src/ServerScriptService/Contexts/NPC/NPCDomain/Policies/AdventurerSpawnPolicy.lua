--!strict

--[=[
	@class AdventurerSpawnPolicy
	Domain policy validating adventurer party spawn parameters.
	@server
]=]

--[[
	AdventurerSpawnPolicy — Domain Policy

	Answers: are these params valid for spawning an adventurer party?

	RESPONSIBILITIES:
	  1. Build a TAdventurerSpawnCandidate from the passed params (no infrastructure reads)
	  2. Evaluate the CanSpawnAdventurerParty spec against the candidate
	  3. Return Ok(nil) on success (no additional state needed by the command)

	All checks are pure: userId range, map non-empty, adventurer stat completeness.
	The AdventurerDataValid field is computed in one pass over the adventurer map.

	RESULT:
	  Ok(nil)   — params are valid for spawning
	  Err(...)  — invalid userId, no adventurers, no spawn points, or missing stat fields

	USAGE:
	  -- Inside a Catch boundary (Application command):
	  Try(self._adventurerSpawnPolicy:Check(userId, adventurers, spawnPoints))
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Result = require(ReplicatedStorage.Utilities.Result)
local Ok, Try = Result.Ok, Result.Try

local NPCSpecs = require(script.Parent.Parent.Specs.NPCSpecs)

local AdventurerSpawnPolicy = {}
AdventurerSpawnPolicy.__index = AdventurerSpawnPolicy

export type TAdventurerSpawnPolicy = typeof(setmetatable({}, AdventurerSpawnPolicy))

function AdventurerSpawnPolicy.new(): TAdventurerSpawnPolicy
	return setmetatable({}, AdventurerSpawnPolicy)
end

-- Check that all adventurers in the map have required stat fields.
-- Required: Type, BaseHP, BaseATK, BaseDEF (used to compute effective stats in spawn)
local function allAdventurersHaveRequiredStats(adventurers: { [string]: any }): boolean
	for _, adventurer in pairs(adventurers) do
		if not adventurer.Type or not adventurer.BaseHP or not adventurer.BaseATK or not adventurer.BaseDEF then
			return false
		end
	end
	return true
end

--[=[
	Validate adventurer party spawn parameters.
	@within AdventurerSpawnPolicy
	@param userId number -- Player ID owning this party
	@param adventurers { [string]: any } -- Map of adventurerId -> adventurer data
	@param spawnPoints { any } -- Candidate spawn locations
	@return Result.Result<nil> -- Ok if valid, error codes if any check fails
]=]
function AdventurerSpawnPolicy:Check(
	userId: number,
	adventurers: { [string]: any },
	spawnPoints: { any }
): Result.Result<nil>
	local candidate: NPCSpecs.TAdventurerSpawnCandidate = {
		UserIdValid         = userId > 0,
		AdventurersProvided = adventurers ~= nil and next(adventurers) ~= nil,
		SpawnPointsProvided = spawnPoints ~= nil and #spawnPoints > 0,
		AdventurerDataValid = not adventurers or allAdventurersHaveRequiredStats(adventurers),
	}

	Try(NPCSpecs.CanSpawnAdventurerParty:IsSatisfiedBy(candidate))

	return Ok(nil)
end

return AdventurerSpawnPolicy
