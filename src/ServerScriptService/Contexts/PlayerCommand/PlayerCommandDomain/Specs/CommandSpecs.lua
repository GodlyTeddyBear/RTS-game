--!strict

--[=[
	@class CommandSpecs
	Composable eligibility specs for validating NPC commands and attack targets.
	@server
]=]

--[[
	CommandSpecs — Composable eligibility rules for player command operations.

	Each spec is a module-level constant built from Spec.new(). Specs are
	pure predicates: given a candidate, return true (Ok) or false (Err).
	They never fetch state — they receive it via the candidate.

	CANDIDATE TYPES:
	  TNPCCommandCandidate    — state needed to evaluate whether an NPC can be commanded
	  TAttackTargetCandidate  — state needed to evaluate whether a target is valid

	INDIVIDUAL SPECS — NPC:
	  NPCExists        — the NPC entity was found for this userId/npcId
	  NPCAlive         — the NPC entity is currently alive
	  NPCIsAdventurer  — the NPC is an adventurer (not an enemy)
	  NPCOwned         — the NPC belongs to this player

	INDIVIDUAL SPECS — AttackTarget:
	  TargetIdValid  — TargetNPCId in data is a string
	  TargetExists   — the target entity was found
	  TargetAlive    — the target entity is currently alive
	  TargetIsEnemy  — the target is an enemy (not an adventurer)

	COMPOSED SPECS:
	  CanCommandNPC    — NPCExists:And(Spec.All({ NPCAlive, NPCIsAdventurer, NPCOwned }))
	  CanAttackTarget  — TargetIdValid:And(Spec.All({ TargetExists, TargetAlive, TargetIsEnemy }))

	CANDIDATE CONSTRUCTION NOTE:
	  Dependent specs (Alive, IsAdventurer, Owned, TargetExists, etc.) are set defensively
	  to true when their root prerequisite is false so only the root error is reported.
	  :And() uses TryAll (not short-circuit), so defensive booleans prevent false positives
	  from the Spec.All accumulation.

	USAGE:
	  -- Per-NPC soft check (no Try — caller inspects result.success):
	  local result = CommandSpecs.CanCommandNPC:IsSatisfiedBy(candidate)
	  if result.success then ... end

	  -- Command-level gate (inside Catch boundary, via Policy):
	  Try(CommandSpecs.CanAttackTarget:IsSatisfiedBy(candidate))
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Spec = require(ReplicatedStorage.Utilities.Specification)
local Errors = require(script.Parent.Parent.Parent.Errors)

-- Candidate types

--[=[
	@interface TNPCCommandCandidate
	@within CommandSpecs
	.NPCExists boolean -- Whether the NPC entity was found
	.NPCAlive boolean -- Whether the NPC is currently alive
	.NPCIsAdventurer boolean -- Whether the NPC is an adventurer
	.NPCOwned boolean -- Whether the NPC belongs to the requesting player
	State snapshot passed to `CanCommandNPC` for evaluation.
]=]
export type TNPCCommandCandidate = {
	NPCExists: boolean,
	NPCAlive: boolean,
	NPCIsAdventurer: boolean,
	NPCOwned: boolean,
}

--[=[
	@interface TAttackTargetCandidate
	@within CommandSpecs
	.TargetIdValid boolean -- Whether the target NPC ID is a non-nil string
	.TargetExists boolean -- Whether the target entity was found
	.TargetAlive boolean -- Whether the target entity is currently alive
	.TargetIsEnemy boolean -- Whether the target is an enemy NPC
	State snapshot passed to `CanAttackTarget` for evaluation.
]=]
export type TAttackTargetCandidate = {
	TargetIdValid: boolean,
	TargetExists: boolean,
	TargetAlive: boolean,
	TargetIsEnemy: boolean,
}

-- Individual specs — NPC command

local NPCExists = Spec.new("NPCNotFound", Errors.NPC_NOT_FOUND,
	function(c: TNPCCommandCandidate) return c.NPCExists end
)

local NPCAlive = Spec.new("NPCNotAlive", Errors.NPC_NOT_ALIVE,
	function(c: TNPCCommandCandidate) return c.NPCAlive end
)

local NPCIsAdventurer = Spec.new("NPCNotAdventurer", Errors.NPC_NOT_ADVENTURER,
	function(c: TNPCCommandCandidate) return c.NPCIsAdventurer end
)

local NPCOwned = Spec.new("NPCNotOwned", Errors.NPC_NOT_OWNED,
	function(c: TNPCCommandCandidate) return c.NPCOwned end
)

-- Individual specs — AttackTarget

local TargetIdValid = Spec.new("TargetNotFound", Errors.TARGET_NOT_FOUND,
	function(c: TAttackTargetCandidate) return c.TargetIdValid end
)

local TargetExists = Spec.new("TargetNotFound", Errors.TARGET_NOT_FOUND,
	function(c: TAttackTargetCandidate) return c.TargetExists end
)

local TargetAlive = Spec.new("TargetNotAlive", Errors.TARGET_NOT_ALIVE,
	function(c: TAttackTargetCandidate) return c.TargetAlive end
)

local TargetIsEnemy = Spec.new("TargetNotEnemy", Errors.TARGET_NOT_ENEMY,
	function(c: TAttackTargetCandidate) return c.TargetIsEnemy end
)

-- Composed specs

--[=[
	@prop CanCommandNPC Spec<TNPCCommandCandidate>
	@within CommandSpecs
	Composed spec that passes when an NPC exists, is alive, is an adventurer, and is owned by the player.
]=]

--[=[
	@prop CanAttackTarget Spec<TAttackTargetCandidate>
	@within CommandSpecs
	Composed spec that passes when the target ID is valid and the target exists, is alive, and is an enemy.
]=]
return table.freeze({
	CanCommandNPC   = NPCExists:And(Spec.All({ NPCAlive, NPCIsAdventurer, NPCOwned })),
	CanAttackTarget = TargetIdValid:And(Spec.All({ TargetExists, TargetAlive, TargetIsEnemy })),
})
