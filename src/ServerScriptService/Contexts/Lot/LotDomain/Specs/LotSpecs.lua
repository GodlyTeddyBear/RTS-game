--!strict

--[[
	LotSpecs — Composable eligibility rules for lot operations.

	Each spec is a module-level constant built from Spec.new(). Specs are
	pure predicates: given a candidate, return true (Ok) or false (Err).
	They never fetch state — they receive it via the candidate.

	CANDIDATE TYPES:
	  TSpawnCandidate   — state needed to evaluate spawn eligibility
	  TCleanupCandidate — state needed to evaluate cleanup eligibility

	INDIVIDUAL SPECS:
	  HasNoActiveLot — player has no currently tracked lot (can spawn)
	  HasActiveLot   — player has a currently tracked entity (can clean up)

	COMPOSED SPECS:
	  CanSpawn   — HasNoActiveLot (single spec, no composition needed)
	  CanCleanup — HasActiveLot  (single spec, no composition needed)

	USAGE:
	  -- Inside a Catch boundary (typically in a Policy):
	  Try(LotSpecs.CanSpawn:IsSatisfiedBy(candidate))
	  Try(LotSpecs.CanCleanup:IsSatisfiedBy(candidate))
]]

--[=[
	@class LotSpecs
	Composable eligibility specifications for lot spawn and cleanup operations.
	@server
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Spec = require(ReplicatedStorage.Utilities.Specification)
local Errors = require(script.Parent.Parent.Parent.Errors)

-- Candidate types

export type TSpawnCandidate = {
	PlayerLotId: string?,  -- nil if player has no active lot
}

export type TCleanupCandidate = {
	Entity: any?,  -- nil if no entity found for player
}

-- Individual specs

local HasNoActiveLot = Spec.new("DuplicateLot", Errors.DUPLICATE_LOT,
	function(ctx: TSpawnCandidate)
		return ctx.PlayerLotId == nil
	end
)

local HasActiveLot = Spec.new("EntityNotFound", Errors.ENTITY_NOT_FOUND,
	function(ctx: TCleanupCandidate)
		return ctx.Entity ~= nil
	end
)

-- Composed specs (single specs here, exposed for symmetry with other contexts)

return table.freeze({
	CanSpawn   = HasNoActiveLot,
	CanCleanup = HasActiveLot,
})
