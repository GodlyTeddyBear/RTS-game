--!strict

--[=[
	@class UnlockSpecs
	Composable eligibility rules for unlock operations.

	Each spec is a module-level constant built from `Spec.new()`. Specs are
	pure predicates: given a candidate, return `Ok` or `Err`. They never
	fetch state — they receive it via the candidate.

	**Candidate types:**
	- `TAutoUnlockCandidate` — state needed to evaluate an automatic unlock
	- `TPurchaseUnlockCandidate` — state needed to evaluate a player-initiated purchase

	**Composed specs:**
	- `CanAutoUnlock` — not already unlocked + all condition thresholds met
	- `CanPurchase` — not already unlocked + all condition thresholds met + sufficient gold
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Spec = require(ReplicatedStorage.Utilities.Specification)
local Errors = require(script.Parent.Parent.Parent.Errors)

--[=[
	@interface TAutoUnlockCandidate
	@within UnlockSpecs
	.IsNotAlreadyUnlocked boolean -- Target is not yet in the player's unlock state
	.MeetsChapter boolean -- Player's current chapter meets the config requirement
	.MeetsCommissionTier boolean -- Player's commission tier meets the config requirement
	.MeetsQuestCount boolean -- Player's completed quest count meets the config requirement
	.MeetsWorkerCount boolean -- Player's hired worker count meets the config requirement
]=]
export type TAutoUnlockCandidate = {
	IsNotAlreadyUnlocked: boolean,
	MeetsChapter: boolean,
	MeetsCommissionTier: boolean,
	MeetsQuestCount: boolean,
	MeetsWorkerCount: boolean,
}

--[=[
	@interface TPurchaseUnlockCandidate
	@within UnlockSpecs
	.IsNotAlreadyUnlocked boolean -- Target is not yet in the player's unlock state
	.MeetsChapter boolean -- Player's current chapter meets the config requirement
	.MeetsCommissionTier boolean -- Player's commission tier meets the config requirement
	.MeetsQuestCount boolean -- Player's completed quest count meets the config requirement
	.MeetsWorkerCount boolean -- Player's hired worker count meets the config requirement
	.HasSufficientGold boolean -- Player has enough gold to cover the unlock cost
]=]
export type TPurchaseUnlockCandidate = {
	IsNotAlreadyUnlocked: boolean,
	MeetsChapter: boolean,
	MeetsCommissionTier: boolean,
	MeetsQuestCount: boolean,
	MeetsWorkerCount: boolean,
	HasSufficientGold: boolean,
}

-- Individual specs

local IsNotAlreadyUnlocked = Spec.new("AlreadyUnlocked", Errors.ALREADY_UNLOCKED,
	function(c: TAutoUnlockCandidate) return c.IsNotAlreadyUnlocked end
)

local MeetsChapter = Spec.new("ChapterTooLow", Errors.CHAPTER_TOO_LOW,
	function(c: TAutoUnlockCandidate) return c.MeetsChapter end
)

local MeetsCommissionTier = Spec.new("CommissionTierTooLow", Errors.COMMISSION_TIER_TOO_LOW,
	function(c: TAutoUnlockCandidate) return c.MeetsCommissionTier end
)

local MeetsQuestCount = Spec.new("NotEnoughQuests", Errors.NOT_ENOUGH_QUESTS,
	function(c: TAutoUnlockCandidate) return c.MeetsQuestCount end
)

local MeetsWorkerCount = Spec.new("NotEnoughWorkers", Errors.NOT_ENOUGH_WORKERS,
	function(c: TAutoUnlockCandidate) return c.MeetsWorkerCount end
)

local HasSufficientGold = Spec.new("InsufficientGold", Errors.INSUFFICIENT_GOLD,
	function(c: TPurchaseUnlockCandidate) return c.HasSufficientGold end
)

-- Composed specs

return table.freeze({
	CanAutoUnlock = IsNotAlreadyUnlocked:And(Spec.All({ MeetsChapter, MeetsCommissionTier, MeetsQuestCount, MeetsWorkerCount })),
	CanPurchase   = IsNotAlreadyUnlocked:And(Spec.All({ MeetsChapter, MeetsCommissionTier, MeetsQuestCount, MeetsWorkerCount, HasSufficientGold })),
})
