--!strict

--[[
	ForgeSpecs — Composable eligibility rules for forge operations.

	Each spec is a module-level constant built from Spec.new(). Specs are
	pure predicates: given a candidate, return true (Ok) or false (Err).
	They never fetch state — they receive it via the candidate.

	CANDIDATE TYPES:
	  TCraftItemCandidate — state needed to evaluate a craft eligibility

	INDIVIDUAL SPECS:
	  RecipeExists        — recipeId maps to a known recipe
	  SufficientMaterials — player has all required ingredient quantities

	COMPOSED SPECS:
	  CanCraftItem — RecipeExists:And(SufficientMaterials):And(InstantCraftRecipe)

	CANDIDATE CONSTRUCTION NOTE:
	  SufficientMaterials and IsInstantCraftRecipe are set defensively when RecipeExists is false
	  so only the root error is reported. :And() uses TryAll (not short-circuit),
	  so the defensive booleans prevent false positives from later specs.

	USAGE:
	  -- Inside a Catch boundary (typically in a Policy):
	  Try(ForgeSpecs.CanCraftItem:IsSatisfiedBy(candidate))
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Spec = require(ReplicatedStorage.Utilities.Specification)
local Errors = require(script.Parent.Parent.Parent.Errors)

--[=[
	@class ForgeSpecs
	Composable specification rules for craft eligibility validation.
	@server
]=]

--[=[
	@type TCraftItemCandidate
	@within ForgeSpecs
	. RecipeExists boolean -- Recipe ID maps to a known recipe in configuration
	. SufficientMaterials boolean -- Player inventory has all required ingredient quantities
	. IsInstantCraftRecipe boolean -- Recipe is instant (no ProcessDurationSeconds or <= 0)
]=]
export type TCraftItemCandidate = {
	RecipeExists: boolean,
	IsRecipeUnlocked: boolean,
	HasRequiredStructure: boolean,
	SufficientMaterials: boolean,
	IsInstantCraftRecipe: boolean,
}

-- Individual specs (implementation details)

-- Recipe must exist in configuration
local RecipeExists = Spec.new("RecipeNotFound", Errors.RECIPE_NOT_FOUND,
	function(c: TCraftItemCandidate) return c.RecipeExists end
)

-- Player must have all required ingredient quantities
local SufficientMaterials = Spec.new("InsufficientMaterials", Errors.INSUFFICIENT_MATERIALS,
	function(c: TCraftItemCandidate) return c.SufficientMaterials end
)

-- Recipe must be unlocked for this player
local RecipeUnlocked = Spec.new("RecipeLocked", Errors.RECIPE_LOCKED,
	function(c: TCraftItemCandidate) return c.IsRecipeUnlocked end
)

-- Future-scope structure requirements currently pass until crafting structures exist.
local RequiredCraftingStructure = Spec.new("RequiredStructureMissing", Errors.REQUIRED_STRUCTURE_MISSING,
	function(c: TCraftItemCandidate) return c.HasRequiredStructure end
)

-- Recipe must be instant-craft (not require a machine/multi-step process)
local InstantCraftRecipe = Spec.new("UseMachineForRecipe", Errors.USE_MACHINE_FOR_RECIPE,
	function(c: TCraftItemCandidate) return c.IsInstantCraftRecipe end
)

--[=[
	@prop CanCraftItem Specification
	@within ForgeSpecs
	Composed specification: recipe exists AND sufficient materials AND instant craft. All three must be satisfied.
]=]

return table.freeze({
	CanCraftItem = RecipeExists:And(RecipeUnlocked):And(RequiredCraftingStructure):And(SufficientMaterials):And(InstantCraftRecipe),
})
