--!strict

--[[
	TailoringSpecs — Composable eligibility rules for tailoring operations.

	Each spec is a module-level constant built from Spec.new(). Specs are
	pure predicates: given a candidate, return true (Ok) or false (Err).
	They never fetch state — they receive it via the candidate.

	CANDIDATE TYPES:
	  TTailItemCandidate — state needed to evaluate a tailoring eligibility

	INDIVIDUAL SPECS:
	  RecipeExists        — recipeId maps to a known tailoring recipe
	  SufficientMaterials — player has all required ingredient quantities

	COMPOSED SPECS:
	  CanTailItem — RecipeExists:And(SufficientMaterials)

	CANDIDATE CONSTRUCTION NOTE:
	  SufficientMaterials is set defensively to true when RecipeExists is false
	  so only the root error is reported. :And() uses TryAll (not short-circuit),
	  so the defensive boolean prevents a false positive from the second spec.

	USAGE:
	  -- Inside a Catch boundary (typically in a Policy):
	  Try(TailoringSpecs.CanTailItem:IsSatisfiedBy(candidate))
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Spec = require(ReplicatedStorage.Utilities.Specification)
local Errors = require(script.Parent.Parent.Parent.Errors)

-- Candidate types

--[=[
	@type TTailItemCandidate
	@within TailoringSpecs
	.RecipeExists boolean -- Whether the recipe ID maps to a known recipe
	.SufficientMaterials boolean -- Whether the player has all required ingredient quantities
	.IsUnlocked boolean -- Whether the player has unlocked the recipe
]=]
export type TTailItemCandidate = {
	RecipeExists: boolean,
	SufficientMaterials: boolean,
	IsUnlocked: boolean,
}

-- Individual specs

local RecipeExists = Spec.new("RecipeNotFound", Errors.RECIPE_NOT_FOUND,
	function(c: TTailItemCandidate) return c.RecipeExists end
)

local SufficientMaterials = Spec.new("InsufficientMaterials", Errors.INSUFFICIENT_MATERIALS,
	function(c: TTailItemCandidate) return c.SufficientMaterials end
)

local RecipeIsUnlocked = Spec.new("RecipeLocked", Errors.RECIPE_LOCKED,
	function(c: TTailItemCandidate) return c.IsUnlocked end
)

-- Composed specs

--[=[
	@class TailoringSpecs
	Composable eligibility specifications for tailoring operations.
	@server
]=]
return table.freeze({
	--[=[
		@prop CanTailItem Specification
		@within TailoringSpecs
		@readonly
		Composed spec: recipe must exist, be unlocked, and have sufficient ingredient materials.
	]=]
	CanTailItem = RecipeIsUnlocked:And(RecipeExists):And(SufficientMaterials),
})
