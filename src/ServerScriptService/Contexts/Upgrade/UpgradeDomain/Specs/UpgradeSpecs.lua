--!strict

--[[
	UpgradeSpecs — Composable eligibility rules for upgrade purchases.

	Each spec is a module-level constant built from Spec.new(). Specs are
	pure predicates: given a candidate, return true (Ok) or false (Err).
	They never fetch state — they receive it via the candidate.

	CANDIDATE TYPES:
	  TPurchaseUpgradeCandidate — state needed to evaluate a purchase

	INDIVIDUAL SPECS:
	  UpgradeExists — upgradeId maps to a known upgrade config entry
	  NotMaxed      — current level < MaxLevel
	  CanAfford     — player has >= final cost in gold

	COMPOSED SPECS:
	  CanPurchase — UpgradeExists:And(NotMaxed):And(CanAfford)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Spec = require(ReplicatedStorage.Utilities.Specification)
local Errors = require(script.Parent.Parent.Parent.Errors)

--[=[
	@class UpgradeSpecs
	Composable specifications for validating upgrade purchase eligibility.
	@server
]=]

--[=[
	@type TPurchaseUpgradeCandidate
	@within UpgradeSpecs
	State needed to evaluate an upgrade purchase operation.
]=]
export type TPurchaseUpgradeCandidate = {
	UpgradeExists: boolean,
	NotMaxed: boolean,
	CanAfford: boolean,
}

local UpgradeExists = Spec.new("UpgradeNotFound", Errors.UPGRADE_NOT_FOUND,
	function(c: TPurchaseUpgradeCandidate) return c.UpgradeExists end
)

local NotMaxed = Spec.new("UpgradeMaxed", Errors.UPGRADE_MAXED,
	function(c: TPurchaseUpgradeCandidate) return c.NotMaxed end
)

local CanAfford = Spec.new("InsufficientGold", Errors.INSUFFICIENT_GOLD,
	function(c: TPurchaseUpgradeCandidate) return c.CanAfford end
)

--[=[
	@prop CanPurchase Spec
	@within UpgradeSpecs
	Composite spec: upgrade must exist, not be at max level, and player can afford.
]=]
return table.freeze({
	CanPurchase = UpgradeExists:And(NotMaxed):And(CanAfford),
})
