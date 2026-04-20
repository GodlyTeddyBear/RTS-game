--!strict

--[[
	SpawnPolicy — Domain Policy

	Answers: is this player in a state that permits spawning a lot?

	RESPONSIBILITIES:
	  1. Fetch player lot tracking state from Infrastructure (PlayersWithLots)
	  2. Build a TSpawnCandidate from that state
	  3. Evaluate the CanSpawn spec against the candidate
	  4. Return Ok on success (no state needed by the command beyond the check)

	RESULT:
	  Ok(nil)   — player is eligible to spawn a lot
	  Err(...)  — player already has an active lot

	USAGE:
	  -- Inside a Catch boundary (Application command):
	  Try(self._spawnPolicy:Check(player))
]]

--[=[
	@class SpawnPolicy
	Domain policy for evaluating lot spawn eligibility.
	@server
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Result = require(ReplicatedStorage.Utilities.Result)
local Ok, Try = Result.Ok, Result.Try

local LotSpecs = require(script.Parent.Parent.Specs.LotSpecs)

local SpawnPolicy = {}
SpawnPolicy.__index = SpawnPolicy

export type TSpawnPolicy = typeof(setmetatable(
	{} :: {
		_playersWithLots: { [Player]: string },
	},
	SpawnPolicy
))

--[=[
	Create a new SpawnPolicy instance.
	@within SpawnPolicy
	@return TSpawnPolicy -- Service instance
]=]
function SpawnPolicy.new(): TSpawnPolicy
	local self = setmetatable({}, SpawnPolicy)
	self._playersWithLots = nil :: any
	return self
end

--[=[
	Initialize with injected dependencies.
	@within SpawnPolicy
	@param registry any -- Registry to resolve dependencies from
	@param _name string -- Service name (unused)
]=]
function SpawnPolicy:Init(registry: any, _name: string)
	self._playersWithLots = registry:Get("PlayersWithLots")
end

--[=[
	Evaluate whether a player is eligible to spawn a lot.
	@within SpawnPolicy
	@param player Player -- The player to check
	@return Result<nil> -- Ok(nil) if eligible, Err if player already has a lot
]=]
function SpawnPolicy:Check(player: Player): Result.Result<nil>
	local candidate: LotSpecs.TSpawnCandidate = {
		PlayerLotId = self._playersWithLots[player],
	}

	Try(LotSpecs.CanSpawn:IsSatisfiedBy(candidate))

	return Ok(nil)
end

return SpawnPolicy
