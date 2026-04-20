--!strict

--[[
	TickSpecs — Per-tick eligibility rules for all worker production systems.

	Covers: mining, general production, forge crafting, brewing, tailoring, and harvesting.
	Each spec is a pure predicate — it receives state via a candidate, never fetches it.

	CANDIDATE TYPES:
	  TMiningTickCandidate     — per-tick mining eligibility (Miner)
	  TProductionTickCandidate — per-tick general production eligibility
	  TForgeTickCandidate      — per-tick forge crafting eligibility
	  TBreweryTickCandidate    — per-tick brewing eligibility
	  TTailoringTickCandidate  — per-tick tailoring eligibility
	  THarvestTickCandidate    — per-tick harvesting eligibility (Lumberjack/Herbalist/Farmer)

	COMPOSED SPECS:
	  CanMineThisTick      — OreExists:And(All({ IsNearOre, MiningComplete }))
	  CanProduceThisTick   — IsEligibleForProduction:And(HasProducedUnit)
	  CanForgeThisTick     — HasRecipeAssigned:And(HasIngredients)
	  CanBrewThisTick      — HasBrewRecipeAssigned:And(HasBrewIngredients)
	  CanTailorThisTick    — HasTailoringRecipeAssigned:And(HasTailoringIngredients)
	  CanHarvestThisTick   — HarvestTargetExists:And(All({ IsNearHarvestTarget, HarvestComplete }))
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Spec = require(ReplicatedStorage.Utilities.Specification)
local Errors = require(script.Parent.Parent.Parent.Errors)

-- Candidate types

export type TMiningTickCandidate = {
	OreExists: boolean,
	IsNearOre: boolean,
	MiningComplete: boolean,
}

export type TProductionTickCandidate = {
	HasAssignment: boolean,
	CanProduce: boolean,
	Production: number,
}

export type TForgeTickCandidate = {
	HasRecipeAssigned: boolean,
	HasIngredients: boolean,
	IsInstantForgeRecipe: boolean,
	RecipeUnlocked: boolean,
	HasRequiredForgeBuilding: boolean,
}

export type TBreweryTickCandidate = {
	HasRecipeAssigned: boolean,
	HasIngredients: boolean,
	RecipeUnlocked: boolean,
	HasRequiredBreweryBuilding: boolean,
}

export type TTailoringTickCandidate = {
	HasRecipeAssigned: boolean,
	HasIngredients: boolean,
}

export type THarvestTickCandidate = {
	TargetExists: boolean,
	IsNearTarget: boolean,
	HarvestComplete: boolean,
}

-- Mining

local OreExists = Spec.new("OreNotFound", Errors.ORE_NOT_FOUND,
	function(ctx: TMiningTickCandidate)
		return ctx.OreExists
	end
)

local IsNearOre = Spec.new("NotNearOre", Errors.NOT_NEAR_ORE,
	function(ctx: TMiningTickCandidate)
		return ctx.IsNearOre
	end
)

local MiningComplete = Spec.new("MiningNotComplete", Errors.MINING_NOT_COMPLETE,
	function(ctx: TMiningTickCandidate)
		return ctx.MiningComplete
	end
)

-- General production

local IsEligibleForProduction = Spec.new("NotEligibleForProduction", Errors.NOT_ELIGIBLE_FOR_PRODUCTION,
	function(ctx: TProductionTickCandidate)
		return ctx.HasAssignment and ctx.CanProduce
	end
)

local HasProducedUnit = Spec.new("ProductionNotReady", Errors.PRODUCTION_NOT_READY,
	function(ctx: TProductionTickCandidate)
		return ctx.Production >= 1
	end
)

-- Forge

local HasRecipeAssigned = Spec.new("NoRecipeAssigned", Errors.NO_RECIPE_ASSIGNED,
	function(ctx: TForgeTickCandidate)
		return ctx.HasRecipeAssigned
	end
)

local HasIngredients = Spec.new("InsufficientIngredients", Errors.INSUFFICIENT_INGREDIENTS,
	function(ctx: TForgeTickCandidate)
		return ctx.HasIngredients
	end
)

local IsInstantForgeRecipe = Spec.new("ForgeRecipeNeedsMachine", Errors.FORGE_RECIPE_NEEDS_MACHINE,
	function(ctx: TForgeTickCandidate)
		return ctx.IsInstantForgeRecipe
	end
)

local ForgeRecipeUnlocked = Spec.new("ForgeRecipeLocked", Errors.FORGE_RECIPE_LOCKED,
	function(ctx: TForgeTickCandidate)
		return ctx.RecipeUnlocked
	end
)

local RequiredForgeBuilding = Spec.new("ForgeBuildingRequired", Errors.FORGE_BUILDING_REQUIRED,
	function(ctx: TForgeTickCandidate)
		return ctx.HasRequiredForgeBuilding
	end
)

-- Brewery

local HasBrewRecipeAssigned = Spec.new("NoBrewRecipeAssigned", Errors.NO_BREW_RECIPE_ASSIGNED,
	function(ctx: TBreweryTickCandidate)
		return ctx.HasRecipeAssigned
	end
)

local HasBrewIngredients = Spec.new("InsufficientBrewIngredients", Errors.INSUFFICIENT_BREW_INGREDIENTS,
	function(ctx: TBreweryTickCandidate)
		return ctx.HasIngredients
	end
)

local BreweryRecipeUnlocked = Spec.new("BreweryRecipeLocked", Errors.BREWERY_RECIPE_LOCKED,
	function(ctx: TBreweryTickCandidate)
		return ctx.RecipeUnlocked
	end
)

local RequiredBreweryBuilding = Spec.new("BreweryBuildingRequired", Errors.BREWERY_BUILDING_REQUIRED,
	function(ctx: TBreweryTickCandidate)
		return ctx.HasRequiredBreweryBuilding
	end
)

-- Tailoring

local HasTailoringRecipeAssigned = Spec.new("NoTailoringRecipeAssigned", Errors.NO_TAILORING_RECIPE_ASSIGNED,
	function(ctx: TTailoringTickCandidate)
		return ctx.HasRecipeAssigned
	end
)

local HasTailoringIngredients = Spec.new("InsufficientTailoringIngredients", Errors.INSUFFICIENT_TAILORING_INGREDIENTS,
	function(ctx: TTailoringTickCandidate)
		return ctx.HasIngredients
	end
)

-- Harvesting (shared by Lumberjack, Herbalist, Farmer)

local HarvestTargetExists = Spec.new("HarvestTargetNotFound", Errors.TREE_NOT_FOUND,
	function(ctx: THarvestTickCandidate)
		return ctx.TargetExists
	end
)

local IsNearHarvestTarget = Spec.new("NotNearHarvestTarget", Errors.NOT_NEAR_TREE,
	function(ctx: THarvestTickCandidate)
		return ctx.IsNearTarget
	end
)

local HarvestComplete = Spec.new("HarvestNotComplete", Errors.CHOPPING_NOT_COMPLETE,
	function(ctx: THarvestTickCandidate)
		return ctx.HarvestComplete
	end
)

return table.freeze({
	CanMineThisTick    = OreExists:And(Spec.All({ IsNearOre, MiningComplete })),
	CanProduceThisTick = IsEligibleForProduction:And(HasProducedUnit),
	CanForgeThisTick   = HasRecipeAssigned:And(HasIngredients):And(IsInstantForgeRecipe):And(ForgeRecipeUnlocked):And(
		RequiredForgeBuilding
	),
	CanBrewThisTick    = HasBrewRecipeAssigned:And(HasBrewIngredients):And(BreweryRecipeUnlocked):And(RequiredBreweryBuilding),
	CanTailorThisTick  = HasTailoringRecipeAssigned:And(HasTailoringIngredients),
	CanHarvestThisTick = HarvestTargetExists:And(Spec.All({ IsNearHarvestTarget, HarvestComplete })),
})
