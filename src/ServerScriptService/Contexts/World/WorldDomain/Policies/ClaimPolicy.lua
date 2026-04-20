--!strict

--[[
	ClaimPolicy — Domain Policy

	Answers: is this player in a state that permits claiming a lot area?

	RESPONSIBILITIES:
	  1. Fetch state from Infrastructure (LotAreaRegistry)
	  2. Build a TClaimCandidate from that state
	  3. Evaluate the CanClaim composed spec against the candidate
	  4. Return fetched state on success (avoids double-read by the caller)

	BOUNDARY:
	  Policies sit between Application and Infrastructure. The Application
	  command calls Policy:Check() instead of manually fetching state and
	  passing it to a validator. The policy owns the fetch-then-evaluate cycle.

	RESULT:
	  Ok({ AreaName })  — player is eligible, area name is ready for claiming
	  Err(...)          — structured failure from spec evaluation or Ensure guard

	USAGE:
	  -- Inside a Catch boundary (Application command):
	  local ctx = Try(self._claimPolicy:Check(player))
	  self._registry:SetClaim(ctx.AreaName, player)
]]

--[=[
	@class ClaimPolicy
	Domain Policy that answers whether a player is eligible to claim a lot area.
	Fetches registry state, builds a candidate, and evaluates the CanClaim spec.
	@server
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Result = require(ReplicatedStorage.Utilities.Result)
local Ok, Try, Ensure = Result.Ok, Result.Try, Result.Ensure

local Errors = require(script.Parent.Parent.Parent.Errors)
local LotAreaSpecs = require(script.Parent.Parent.Specs.LotAreaSpecs)

local ClaimPolicy = {}
ClaimPolicy.__index = ClaimPolicy

export type TClaimPolicy = typeof(setmetatable(
	{} :: {
		_registry: any,
	},
	ClaimPolicy
))

--[=[
	@interface TClaimPolicyResult
	Success result from a claim eligibility check.
	@within ClaimPolicy
	.AreaName string -- The available area the player can claim
]=]
export type TClaimPolicyResult = {
	AreaName: string,
}

--[=[
	Create a new ClaimPolicy.
	@within ClaimPolicy
	@return TClaimPolicy
]=]
function ClaimPolicy.new(): TClaimPolicy
	local self = setmetatable({}, ClaimPolicy)
	self._registry = nil :: any
	return self
end

--[=[
	Initialize the policy with a LotAreaRegistry reference.
	Called by the DDD Registry pattern during KnitInit.
	@within ClaimPolicy
	@param registry any -- The DDD Registry instance
	@param _name string -- The service name (unused)
]=]
function ClaimPolicy:Init(registry: any, _name: string)
	self._registry = registry:Get("LotAreaRegistry")
end

--[=[
	Check whether a player is eligible to claim a lot area.
	Fetches current state from the registry and evaluates the CanClaim spec.
	@within ClaimPolicy
	@param player Player -- The player requesting the claim
	@return Result.Result<TClaimPolicyResult> -- Ok(AreaName) or Err on ineligibility
]=]
function ClaimPolicy:Check(player: Player): Result.Result<TClaimPolicyResult>
	local areaName = self._registry:FindFirstAvailable()
	Ensure(areaName, "NoAreasAvailable", Errors.NO_AREAS_AVAILABLE)

	local candidate: LotAreaSpecs.TClaimCandidate = {
		AreaName = areaName,
		AreaExists = self._registry:AreaExists(areaName),
		AreaClaimedBy = self._registry:GetClaimant(areaName),
		PlayerCurrentClaim = self._registry:GetPlayerClaim(player),
	}

	Try(LotAreaSpecs.CanClaim:IsSatisfiedBy(candidate))

	return Ok({
		AreaName = areaName,
	})
end

return ClaimPolicy
