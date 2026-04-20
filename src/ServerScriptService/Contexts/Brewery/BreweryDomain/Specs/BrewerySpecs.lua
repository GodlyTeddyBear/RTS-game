--!strict

--[[
	BrewerySpecs — Composable eligibility rules for brewery operations.

	Each spec is a module-level constant built from Spec.new(). Specs are
	pure predicates: given a candidate, return true (Ok) or false (Err).
	They never fetch state — they receive it via the candidate.

	CANDIDATE TYPES:
	  TBrewItemCandidate — state needed to evaluate a brew eligibility

	INDIVIDUAL SPECS:
	  RecipeExists        — recipeId maps to a known brewery recipe
	  SufficientMaterials — player has all required ingredient quantities

	COMPOSED SPECS:
	  CanBrewItem — RecipeExists:And(SufficientMaterials)

	CANDIDATE CONSTRUCTION NOTE:
	  SufficientMaterials is set defensively to true when RecipeExists is false
	  so only the root error is reported.

	USAGE:
	  -- Inside a Catch boundary (typically in a Policy):
	  Try(BrewerySpecs.CanBrewItem:IsSatisfiedBy(candidate))
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Spec = require(ReplicatedStorage.Utilities.Specification)
local Errors = require(script.Parent.Parent.Parent.Errors)

--[=[
	@class BrewerySpecs
	Composable specifications for validating brew eligibility.
	@server
]=]

--[=[
	@type TBrewItemCandidate
	@within BrewerySpecs
	State needed to evaluate a brew operation eligibility.
]=]
-- Candidate types

export type TBrewItemCandidate = {
	RecipeExists: boolean,
	SufficientMaterials: boolean,
	IsUnlocked: boolean,
}

-- Individual specs

local RecipeExists = Spec.new("RecipeNotFound", Errors.RECIPE_NOT_FOUND,
	function(c: TBrewItemCandidate) return c.RecipeExists end
)

local SufficientMaterials = Spec.new("InsufficientMaterials", Errors.INSUFFICIENT_MATERIALS,
	function(c: TBrewItemCandidate) return c.SufficientMaterials end
)

local RecipeIsUnlocked = Spec.new("RecipeLocked", Errors.RECIPE_LOCKED,
	function(c: TBrewItemCandidate) return c.IsUnlocked end
)

-- Composed specs

--[=[
	@prop CanBrewItem Spec
	@within BrewerySpecs
	Composite spec: recipe must exist, be unlocked, and player has sufficient materials.
]=]

return table.freeze({
	CanBrewItem = RecipeIsUnlocked:And(RecipeExists):And(SufficientMaterials),
})
