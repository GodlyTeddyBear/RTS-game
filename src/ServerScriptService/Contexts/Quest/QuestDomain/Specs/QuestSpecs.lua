--!strict

--[[
	QuestSpecs — Composable eligibility rules for quest operations.

	Each spec is a module-level constant built from Spec.new(). Specs are
	pure predicates: given a candidate, return true (Ok) or false (Err).
	They never fetch state — they receive it via the candidate.

	CANDIDATE TYPES:
	  TDepartCandidate — state needed to evaluate expedition departure eligibility
	  TFleeCandidate   — state needed to evaluate expedition flee eligibility

	INDIVIDUAL SPECS (depart):
	  ZoneExists               — zone ID exists in ZoneConfig
	  PartySizeAtLeast         — party meets the zone's MinPartySize
	  PartySizeAtMost          — party does not exceed the zone's MaxPartySize
	  NoActiveExpedition       — player has no currently active expedition
	  AllAdventurersExist      — every adventurer in the party is in the guild roster
	  NoAdventurersOnExpedition — no party adventurer is already on an expedition

	INDIVIDUAL SPECS (flee):
	  ExpeditionExists    — player has an active expedition
	  ExpeditionInCombat  — active expedition status is InCombat

	COMPOSED SPECS:
	  CanDepart — ZoneExists:And(All({ PartySizeAtLeast, PartySizeAtMost, NoActiveExpedition,
	                                   AllAdventurersExist, NoAdventurersOnExpedition }))
	  CanFlee   — ExpeditionExists:And(ExpeditionInCombat)

	CANDIDATE CONSTRUCTION NOTE:
	  PartySizeAtLeast/AtMost are set to true when zone is nil — ZoneExists:And will
	  short-circuit before those specs run, preventing false positives in Spec.All.

	USAGE:
	  Try(QuestSpecs.CanDepart:IsSatisfiedBy(candidate))
	  Try(QuestSpecs.CanFlee:IsSatisfiedBy(candidate))
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Spec = require(ReplicatedStorage.Utilities.Specification)
local Errors = require(script.Parent.Parent.Parent.Errors)

-- Candidate types

export type TDepartCandidate = {
	ZoneExists: boolean,
	ZoneUnlocked: boolean,
	PartySizeAtLeast: boolean,
	PartySizeAtMost: boolean,
	NoActiveExpedition: boolean,
	AllAdventurersExist: boolean,
	NoAdventurersOnExpedition: boolean,
}

export type TFleeCandidate = {
	ExpeditionExists: boolean,
	ExpeditionInCombat: boolean,
}

-- Individual specs (depart)

local ZoneExists = Spec.new("ZoneNotFound", Errors.ZONE_NOT_FOUND,
	function(ctx: TDepartCandidate)
		return ctx.ZoneExists
	end
)

local ZoneUnlocked = Spec.new("ZoneLocked", Errors.ZONE_LOCKED,
	function(ctx: TDepartCandidate)
		return ctx.ZoneUnlocked
	end
)

local PartySizeAtLeast = Spec.new("PartyTooSmall", Errors.PARTY_TOO_SMALL,
	function(ctx: TDepartCandidate)
		return ctx.PartySizeAtLeast
	end
)

local PartySizeAtMost = Spec.new("PartyTooLarge", Errors.PARTY_TOO_LARGE,
	function(ctx: TDepartCandidate)
		return ctx.PartySizeAtMost
	end
)

local NoActiveExpedition = Spec.new("ExpeditionAlreadyActive", Errors.EXPEDITION_ALREADY_ACTIVE,
	function(ctx: TDepartCandidate)
		return ctx.NoActiveExpedition
	end
)

local AllAdventurersExist = Spec.new("AdventurerNotFound", Errors.ADVENTURER_NOT_FOUND,
	function(ctx: TDepartCandidate)
		return ctx.AllAdventurersExist
	end
)

local NoAdventurersOnExpedition = Spec.new("AdventurerAlreadyDeparted", Errors.ADVENTURER_ALREADY_DEPARTED,
	function(ctx: TDepartCandidate)
		return ctx.NoAdventurersOnExpedition
	end
)

-- Individual specs (flee)

local ExpeditionExists = Spec.new("NoActiveExpedition", Errors.NO_ACTIVE_EXPEDITION,
	function(ctx: TFleeCandidate)
		return ctx.ExpeditionExists
	end
)

local ExpeditionInCombat = Spec.new("ExpeditionNotInCombat", Errors.EXPEDITION_NOT_IN_COMBAT,
	function(ctx: TFleeCandidate)
		return ctx.ExpeditionInCombat
	end
)

-- Composed specs

return table.freeze({
	CanDepart = ZoneExists:And(Spec.All({
		ZoneUnlocked,
		PartySizeAtLeast,
		PartySizeAtMost,
		NoActiveExpedition,
		AllAdventurersExist,
		NoAdventurersOnExpedition,
	})),
	CanFlee = ExpeditionExists:And(ExpeditionInCombat),
})
