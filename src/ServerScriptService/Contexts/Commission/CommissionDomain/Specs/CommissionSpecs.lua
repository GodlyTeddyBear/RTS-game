--!strict

--[=[
	@class CommissionSpecs
	Composable eligibility specs for all commission operations (accept, deliver, abandon, unlock tier).
	@server
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Spec = require(ReplicatedStorage.Utilities.Specification)
local Errors = require(script.Parent.Parent.Parent.Errors)

--[=[
	@interface TAcceptCommissionCandidate
	@within CommissionSpecs
	.CommissionIdValid boolean -- Whether the provided commission ID is non-empty
	.SlotAvailable boolean -- Whether the player's active list is below the cap
	.CommissionOnBoard boolean -- Whether the commission exists on the board
]=]

--[=[
	@interface TDeliverCommissionCandidate
	@within CommissionSpecs
	.CommissionIdValid boolean -- Whether the provided commission ID is non-empty
	.CommissionActive boolean -- Whether the commission is in the player's active list
	.SufficientItems boolean -- Whether the player has enough items to fulfil the requirement
]=]

--[=[
	@interface TAbandonCommissionCandidate
	@within CommissionSpecs
	.CommissionIdValid boolean -- Whether the provided commission ID is non-empty
	.CommissionInActive boolean -- Whether the commission is in the player's active list
]=]

--[=[
	@interface TUnlockTierCandidate
	@within CommissionSpecs
	.NextTierExists boolean -- Whether the next tier is defined in config
	.SufficientTokens boolean -- Whether the player has enough tokens for the unlock cost
]=]

-- Candidate types

export type TAcceptCommissionCandidate = {
	CommissionIdValid: boolean,
	SlotAvailable: boolean,
	CommissionOnBoard: boolean,
}

export type TDeliverCommissionCandidate = {
	CommissionIdValid: boolean,
	CommissionActive: boolean,
	SufficientItems: boolean,
}

export type TAbandonCommissionCandidate = {
	CommissionIdValid: boolean,
	CommissionInActive: boolean,
}

export type TUnlockTierCandidate = {
	NextTierExists: boolean,
	SufficientTokens: boolean,
}

-- Individual specs — Accept

local CommissionIdValid = Spec.new("InvalidInput", Errors.INVALID_COMMISSION_ID,
	function(c: TAcceptCommissionCandidate) return c.CommissionIdValid end
)

local SlotAvailable = Spec.new("MaxActiveReached", Errors.MAX_ACTIVE_REACHED,
	function(c: TAcceptCommissionCandidate) return c.SlotAvailable end
)

local CommissionOnBoard = Spec.new("CommissionNotFound", Errors.COMMISSION_NOT_FOUND,
	function(c: TAcceptCommissionCandidate) return c.CommissionOnBoard end
)

-- Individual specs — Deliver

local DeliverCommissionIdValid = Spec.new("InvalidInput", Errors.INVALID_COMMISSION_ID,
	function(c: TDeliverCommissionCandidate) return c.CommissionIdValid end
)

local CommissionActive = Spec.new("CommissionNotActive", Errors.COMMISSION_NOT_ACTIVE,
	function(c: TDeliverCommissionCandidate) return c.CommissionActive end
)

local SufficientItems = Spec.new("InsufficientItems", Errors.INSUFFICIENT_ITEMS,
	function(c: TDeliverCommissionCandidate) return c.SufficientItems end
)

-- Individual specs — Abandon

local AbandonCommissionIdValid = Spec.new("InvalidInput", Errors.INVALID_COMMISSION_ID,
	function(c: TAbandonCommissionCandidate) return c.CommissionIdValid end
)

local CommissionInActive = Spec.new("CommissionNotActive", Errors.COMMISSION_NOT_ACTIVE,
	function(c: TAbandonCommissionCandidate) return c.CommissionInActive end
)

-- Individual specs — UnlockTier

local NextTierExists = Spec.new("TierAlreadyMax", Errors.TIER_ALREADY_MAX,
	function(c: TUnlockTierCandidate) return c.NextTierExists end
)

local SufficientTokens = Spec.new("InsufficientTokens", Errors.INSUFFICIENT_TOKENS,
	function(c: TUnlockTierCandidate) return c.SufficientTokens end
)

--[=[
	@prop CanAcceptCommission Spec
	@within CommissionSpecs
	Composed spec that validates a commission accept: ID valid, slot available, and commission on board.
]=]

--[=[
	@prop CanDeliverCommission Spec
	@within CommissionSpecs
	Composed spec that validates a commission delivery: ID valid, commission active, and sufficient items.
]=]

--[=[
	@prop CanAbandonCommission Spec
	@within CommissionSpecs
	Composed spec that validates a commission abandon: ID valid and commission in active list.
]=]

--[=[
	@prop CanUnlockTier Spec
	@within CommissionSpecs
	Composed spec that validates a tier unlock: next tier exists and sufficient tokens.
]=]

-- Composed specs

return table.freeze({
	CanAcceptCommission  = CommissionIdValid:And(Spec.All({ SlotAvailable, CommissionOnBoard })),
	CanDeliverCommission = DeliverCommissionIdValid:And(Spec.All({ CommissionActive, SufficientItems })),
	CanAbandonCommission = AbandonCommissionIdValid:And(CommissionInActive),
	CanUnlockTier        = NextTierExists:And(SufficientTokens),
})
