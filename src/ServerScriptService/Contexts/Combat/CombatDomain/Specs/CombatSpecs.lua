--!strict

--[[
	CombatSpecs — Composable eligibility rules for combat operations.

	Each spec is a module-level constant built from Spec.new(). Specs are
	pure predicates: given a candidate, return true (Ok) or false (Err).
	They never fetch state — they receive it via the candidate.

	CANDIDATE TYPES:
	  TStartCombatCandidate    — state needed to evaluate a combat start eligibility
	  TBTTickCandidate         — state needed to evaluate per-entity BT tick eligibility
	  TWaveCompletionCandidate — state needed to evaluate wave/party completion

	INDIVIDUAL SPECS:
	  UserIdValid      — userId is a positive number
	  HasAdventurers   — at least one adventurer entity provided
	  HasEnemies       — at least one enemy entity provided
	  NoCombatActive   — no combat is currently active for this user
	  IsNotManualMode  — NPC is not in manual control mode
	  IsNotCommitted   — current action is not committed (can be interrupted)
	  HasBehaviorTree  — entity has a behavior tree assigned
	  BTIntervalReady  — enough time has elapsed since last BT tick
	  AllEnemiesDead   — no alive enemies remain (wave complete)
	  AllAdventurersDead — no alive adventurers remain (party wiped)

	COMPOSED SPECS:
	  CanStartCombat     — UserIdValid:And(Spec.All({ HasAdventurers, HasEnemies, NoCombatActive }))
	  CanTickBehaviorTree — IsNotManualMode:And(Spec.All({ IsNotCommitted, HasBehaviorTree, BTIntervalReady }))
	  IsWaveComplete     — AllEnemiesDead
	  IsPartyWiped       — AllAdventurersDead

	USAGE:
	  -- Inside a Catch boundary (typically in a Policy):
	  Try(CombatSpecs.CanStartCombat:IsSatisfiedBy(candidate))
	  Try(CombatSpecs.CanTickBehaviorTree:IsSatisfiedBy(candidate))
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Spec = require(ReplicatedStorage.Utilities.Specification)
local Errors = require(script.Parent.Parent.Parent.Errors)

-- Candidate types

export type TStartCombatCandidate = {
	UserIdValid: boolean,
	HasAdventurers: boolean,
	HasEnemies: boolean,
	NoCombatActive: boolean,
}

export type TBTTickCandidate = {
	IsNotManualMode: boolean,
	IsNotCommitted: boolean,
	HasBehaviorTree: boolean,
	BTIntervalReady: boolean,
}

export type TWaveCompletionCandidate = {
	AllEnemiesDead: boolean,
	AllAdventurersDead: boolean,
}

-- Individual specs

local UserIdValid = Spec.new("InvalidUserId", Errors.INVALID_USER_ID,
	function(c: TStartCombatCandidate) return c.UserIdValid end
)

local HasAdventurers = Spec.new("NoAdventurerEntities", Errors.NO_ADVENTURER_ENTITIES,
	function(c: TStartCombatCandidate) return c.HasAdventurers end
)

local HasEnemies = Spec.new("NoEnemyEntities", Errors.NO_ENEMY_ENTITIES,
	function(c: TStartCombatCandidate) return c.HasEnemies end
)

local NoCombatActive = Spec.new("CombatAlreadyActive", Errors.COMBAT_ALREADY_ACTIVE,
	function(c: TStartCombatCandidate) return c.NoCombatActive end
)

-- BT tick specs

local IsNotManualMode = Spec.new("IsManualMode", Errors.IS_MANUAL_MODE,
	function(c: TBTTickCandidate) return c.IsNotManualMode end
)

local IsNotCommitted = Spec.new("ActionIsCommitted", Errors.ACTION_IS_COMMITTED,
	function(c: TBTTickCandidate) return c.IsNotCommitted end
)

local HasBehaviorTree = Spec.new("NoBehaviorTree", Errors.NO_BEHAVIOR_TREE,
	function(c: TBTTickCandidate) return c.HasBehaviorTree end
)

local BTIntervalReady = Spec.new("BTNotReady", Errors.BT_NOT_READY,
	function(c: TBTTickCandidate) return c.BTIntervalReady end
)

-- Wave completion specs

local AllEnemiesDead = Spec.new("WaveNotComplete", Errors.WAVE_NOT_COMPLETE,
	function(c: TWaveCompletionCandidate) return c.AllEnemiesDead end
)

local AllAdventurersDead = Spec.new("PartyNotWiped", Errors.PARTY_NOT_WIPED,
	function(c: TWaveCompletionCandidate) return c.AllAdventurersDead end
)

-- Composed specs

return table.freeze({
	CanStartCombat      = UserIdValid:And(Spec.All({ HasAdventurers, HasEnemies, NoCombatActive })),
	CanTickBehaviorTree = IsNotManualMode:And(Spec.All({ IsNotCommitted, HasBehaviorTree, BTIntervalReady })),
	IsWaveComplete      = AllEnemiesDead,
	IsPartyWiped        = AllAdventurersDead,
})
