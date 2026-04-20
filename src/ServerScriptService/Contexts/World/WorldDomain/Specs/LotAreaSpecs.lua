--!strict

--[[
	LotAreaSpecs — Composable eligibility rules for lot area operations.

	Each spec is a module-level constant built from Spec.new(). Specs are
	pure predicates: given a candidate, return true (Ok) or false (Err).
	They never fetch state — they receive it via the candidate.

	CANDIDATE TYPES:
	  TClaimCandidate   — state needed to evaluate claim eligibility
	  TReleaseCandidate — state needed to evaluate release eligibility

	  All specs that compose together share the same candidate type.
	  The policy is responsible for building the candidate from infrastructure.

	INDIVIDUAL SPECS:
	  AreaNameValid    — area name passes LotAreaId value object construction
	  AreaExists       — area is registered in the LotAreaRegistry
	  AreaNotClaimed   — area has no current claimant
	  PlayerHasNoClaim — player does not already have a claimed area
	  PlayerHasClaim   — player currently has a claimed area

	COMPOSED SPECS:
	  CanClaim   — AreaNameValid AND (AreaExists + AreaNotClaimed + PlayerHasNoClaim)
	               AreaNameValid short-circuits; the rest accumulate via TryAll.
	  CanRelease — PlayerHasClaim (single spec, no composition needed)

	USAGE:
	  -- Inside a Catch boundary (typically in a Policy):
	  Try(LotAreaSpecs.CanClaim:IsSatisfiedBy(candidate))
	  Try(LotAreaSpecs.CanRelease:IsSatisfiedBy(candidate))
]]

--[=[
	@class LotAreaSpecs
	Composable eligibility rules for lot area operations.
	Specs are pure predicates that evaluate candidate state without side effects.
	Composed specs handle short-circuit and accumulation semantics.
	@server
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Spec = require(ReplicatedStorage.Utilities.Specification)
local Errors = require(script.Parent.Parent.Parent.Errors)
local LotAreaId = require(script.Parent.Parent.ValueObjects.LotAreaId)

-- Candidate types

--[=[
	@interface TClaimCandidate
	State required to evaluate lot area claim eligibility.
	@within LotAreaSpecs
	.AreaName string -- The lot area name being claimed
	.AreaExists boolean -- Whether the area is registered in the registry
	.AreaClaimedBy Player? -- The current claimant (nil if unclaimed)
	.PlayerCurrentClaim string? -- The area this player currently claims (nil if none)
]=]
export type TClaimCandidate = {
	AreaName: string,
	AreaExists: boolean,
	AreaClaimedBy: Player?,
	PlayerCurrentClaim: string?,
}

--[=[
	@interface TReleaseCandidate
	State required to evaluate lot area release eligibility.
	@within LotAreaSpecs
	.PlayerCurrentClaim string? -- The area this player currently claims (nil if none)
]=]
export type TReleaseCandidate = {
	PlayerCurrentClaim: string?,
}

-- Individual specs

local AreaNameValid = Spec.new("AreaNotFound", Errors.AREA_NOT_FOUND, function(ctx: TClaimCandidate)
	local ok = pcall(function()
		LotAreaId.new(ctx.AreaName)
	end)
	return ok
end)

local AreaExists = Spec.new("AreaNotFound", Errors.AREA_NOT_FOUND, function(ctx: TClaimCandidate)
	return ctx.AreaExists == true
end)

local AreaNotClaimed = Spec.new("AreaAlreadyClaimed", Errors.AREA_ALREADY_CLAIMED, function(ctx: TClaimCandidate)
	return ctx.AreaClaimedBy == nil
end)

local PlayerHasNoClaim = Spec.new("PlayerAlreadyHasClaim", Errors.PLAYER_ALREADY_HAS_CLAIM, function(ctx: TClaimCandidate)
	return ctx.PlayerCurrentClaim == nil
end)

local PlayerHasClaim = Spec.new("PlayerHasNoClaim", Errors.PLAYER_HAS_NO_CLAIM, function(ctx: TReleaseCandidate)
	return ctx.PlayerCurrentClaim ~= nil
end)

-- Composed specs

local CanClaim = AreaNameValid:And(Spec.All({ AreaExists, AreaNotClaimed, PlayerHasNoClaim }))
local CanRelease = PlayerHasClaim

--[=[
	@prop CanClaim Spec
	@within LotAreaSpecs
	Composed spec for claim eligibility: area name must be valid, area must exist and be unclaimed, player must not already have a claim.
	Uses short-circuit AND composition: AreaNameValid gates the rest.
]=]

--[=[
	@prop CanRelease Spec
	@within LotAreaSpecs
	Composed spec for release eligibility: player must currently have a claim.
]=]

return table.freeze({
	CanClaim = CanClaim,
	CanRelease = CanRelease,
})
