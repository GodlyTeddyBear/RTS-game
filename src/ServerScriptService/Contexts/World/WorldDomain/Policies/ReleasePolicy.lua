--!strict

--[[
	ReleasePolicy — Domain Policy

	Answers: is this player in a state that permits releasing their lot area claim?

	RESPONSIBILITIES:
	  1. Fetch player claim state from Infrastructure (LotAreaRegistry)
	  2. Build a TReleaseCandidate from that state
	  3. Evaluate the CanRelease spec against the candidate
	  4. Return fetched state on success (avoids double-read by the caller)

	RESULT:
	  Ok({ PlayerCurrentClaim })  — player has an active claim that can be released
	  Err(...)                    — player has no claim (from spec evaluation)

	USAGE:
	  -- Inside a Catch boundary (Application command):
	  Try(self._releasePolicy:Check(player))
	  local releasedArea = self._registry:ReleaseClaim(player)
]]

--[=[
	@class ReleasePolicy
	Domain Policy that answers whether a player is eligible to release their lot area claim.
	Fetches registry state, builds a candidate, and evaluates the CanRelease spec.
	@server
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Result = require(ReplicatedStorage.Utilities.Result)
local Ok, Try = Result.Ok, Result.Try

local LotAreaSpecs = require(script.Parent.Parent.Specs.LotAreaSpecs)

local ReleasePolicy = {}
ReleasePolicy.__index = ReleasePolicy

export type TReleasePolicy = typeof(setmetatable(
	{} :: {
		_registry: any,
	},
	ReleasePolicy
))

--[=[
	@interface TReleasePolicyResult
	Success result from a release eligibility check.
	@within ReleasePolicy
	.PlayerCurrentClaim string -- The area the player currently claims
]=]
export type TReleasePolicyResult = {
	PlayerCurrentClaim: string,
}

--[=[
	Create a new ReleasePolicy.
	@within ReleasePolicy
	@return TReleasePolicy
]=]
function ReleasePolicy.new(): TReleasePolicy
	local self = setmetatable({}, ReleasePolicy)
	self._registry = nil :: any
	return self
end

--[=[
	Initialize the policy with a LotAreaRegistry reference.
	Called by the DDD Registry pattern during KnitInit.
	@within ReleasePolicy
	@param registry any -- The DDD Registry instance
	@param _name string -- The service name (unused)
]=]
function ReleasePolicy:Init(registry: any, _name: string)
	self._registry = registry:Get("LotAreaRegistry")
end

--[=[
	Check whether a player is eligible to release their lot area claim.
	Fetches current claim state from the registry and evaluates the CanRelease spec.
	@within ReleasePolicy
	@param player Player -- The player requesting the release
	@return Result.Result<TReleasePolicyResult> -- Ok(PlayerCurrentClaim) or Err if player has no claim
]=]
function ReleasePolicy:Check(player: Player): Result.Result<TReleasePolicyResult>
	local candidate: LotAreaSpecs.TReleaseCandidate = {
		PlayerCurrentClaim = self._registry:GetPlayerClaim(player),
	}

	Try(LotAreaSpecs.CanRelease:IsSatisfiedBy(candidate))

	return Ok({
		PlayerCurrentClaim = candidate.PlayerCurrentClaim :: string,
	})
end

return ReleasePolicy
