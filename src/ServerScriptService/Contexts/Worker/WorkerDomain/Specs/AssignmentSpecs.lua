--!strict

--[[
	AssignmentSpecs — Eligibility rules for worker assignment operations.

	Covers: hire, role assignment, and all target/recipe assignment checks.
	Each spec is a pure predicate — it receives state via a candidate, never fetches it.

	CANDIDATE TYPES:
	  THireCandidate                   — can this worker type be hired?
	  TAssignRoleCandidate             — can this worker be assigned a role?
	  TAssignMinerOreCandidate         — can this Miner be assigned an ore type?
	  TAssignForgeRecipeCandidate      — can this Forge worker be assigned a recipe?
	  TAssignBreweryRecipeCandidate    — can this Brewer be assigned a brew recipe?
	  TAssignTailoringRecipeCandidate  — can this Tailor be assigned a tailoring recipe?
	  TAssignLumberjackTargetCandidate — can this Lumberjack be assigned a tree?
	  TAssignHerbalistTargetCandidate  — can this Herbalist be assigned a plant?
	  TAssignFarmerTargetCandidate     — can this Farmer be assigned a crop?

	COMPOSED SPECS:
	  CanHire                   — WorkerTypeValid
	  CanAssignRole             — WorkerExists:And(RoleValid)
	  CanAssignMinerOre         — WorkerExists:And(All({ IsMiner, OreTypeValid, LotHasMines, OreInLot }))
	  CanAssignForgeRecipe      — WorkerExists:And(All({ IsForge, RecipeValid, RecipeIsAutomatable }))
	  CanAssignBreweryRecipe    — WorkerExists:And(All({ IsBrewery, BreweryRecipeValid, BreweryRecipeIsAutomatable }))
	  CanAssignTailoringRecipe  — WorkerExists:And(All({ IsTailor, TailoringRecipeValid, TailoringRecipeIsAutomatable }))
	  CanAssignLumberjackTarget — WorkerExists:And(All({ IsLumberjack, TreeTypeValid, LotHasForest, TreeInLot }))
	  CanAssignHerbalistTarget  — WorkerExists:And(All({ IsHerbalist, PlantTypeValid, LotHasGarden, PlantInLot }))
	  CanAssignFarmerTarget     — WorkerExists:And(All({ IsFarmer, CropTypeValid, LotHasFarm, CropInLot }))
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Spec = require(ReplicatedStorage.Utilities.Specification)
local Errors = require(script.Parent.Parent.Parent.Errors)

-- Candidate types

export type THireCandidate = {
	WorkerTypeExists: boolean,
}

export type TAssignRoleCandidate = {
	Entity: any?,
	RoleExists: boolean,
	IsUnlocked: boolean,
}

export type TAssignMinerOreCandidate = {
	Entity: any?,
	IsMiner: boolean,
	OreTypeExists: boolean,
	MinesFolderExists: boolean,
	OreInLot: boolean,
	IsUnlocked: boolean,
	WorkersAtOre: number,
	MaxWorkers: number,
}

export type TAssignForgeRecipeCandidate = {
	Entity: any?,
	IsForge: boolean,
	RecipeExists: boolean,
	RecipeAutomatable: boolean,
	RecipeUnlocked: boolean,
	HasRequiredForgeBuilding: boolean,
}

export type TAssignBreweryRecipeCandidate = {
	Entity: any?,
	IsBrewery: boolean,
	RecipeExists: boolean,
	RecipeAutomatable: boolean,
	RecipeUnlocked: boolean,
	HasRequiredBreweryBuilding: boolean,
}

export type TAssignTailoringRecipeCandidate = {
	Entity: any?,
	IsTailor: boolean,
	RecipeExists: boolean,
	RecipeAutomatable: boolean,
}

export type TAssignLumberjackTargetCandidate = {
	Entity: any?,
	IsLumberjack: boolean,
	TreeTypeExists: boolean,
	ForestFolderExists: boolean,
	TreeInLot: boolean,
	WorkersAtTree: number,
	MaxWorkers: number,
	IsUnlocked: boolean,
}

export type TAssignHerbalistTargetCandidate = {
	Entity: any?,
	IsHerbalist: boolean,
	PlantTypeExists: boolean,
	GardenFolderExists: boolean,
	PlantInLot: boolean,
	WorkersAtPlant: number,
	MaxWorkers: number,
	IsUnlocked: boolean,
}

export type TAssignFarmerTargetCandidate = {
	Entity: any?,
	IsFarmer: boolean,
	CropTypeExists: boolean,
	FarmFolderExists: boolean,
	CropInLot: boolean,
	WorkersAtCrop: number,
	MaxWorkers: number,
	IsUnlocked: boolean,
}

-- Hire

local WorkerTypeValid = Spec.new("InvalidWorkerType", Errors.INVALID_WORKER_TYPE,
	function(ctx: THireCandidate)
		return ctx.WorkerTypeExists
	end
)

-- Role assignment

local WorkerExists = Spec.new("WorkerNotFound", Errors.WORKER_NOT_FOUND,
	function(ctx: TAssignRoleCandidate)
		return ctx.Entity ~= nil
	end
)

local RoleValid = Spec.new("InvalidRole", Errors.INVALID_ROLE,
	function(ctx: TAssignRoleCandidate)
		return ctx.RoleExists
	end
)

local RoleIsUnlocked = Spec.new("NotUnlocked", Errors.NOT_UNLOCKED,
	function(ctx: TAssignRoleCandidate)
		return ctx.IsUnlocked
	end
)

-- Miner ore assignment

local IsMiner = Spec.new("WorkerNotMiner", Errors.WORKER_NOT_MINER,
	function(ctx: TAssignMinerOreCandidate)
		return ctx.IsMiner
	end
)

local OreTypeValid = Spec.new("InvalidOreType", Errors.INVALID_ORE_TYPE,
	function(ctx: TAssignMinerOreCandidate)
		return ctx.OreTypeExists
	end
)

local LotHasMines = Spec.new("LotNotFound", Errors.LOT_NOT_FOUND,
	function(ctx: TAssignMinerOreCandidate)
		return ctx.MinesFolderExists
	end
)

local OreInLot = Spec.new("OreNotInLot", Errors.ORE_NOT_IN_LOT,
	function(ctx: TAssignMinerOreCandidate)
		return ctx.OreInLot
	end
)

-- Forge recipe assignment

local IsForge = Spec.new("WorkerNotForge", Errors.WORKER_NOT_FORGE,
	function(ctx: TAssignForgeRecipeCandidate)
		return ctx.IsForge
	end
)

local RecipeValid = Spec.new("RecipeNotFound", Errors.RECIPE_NOT_FOUND,
	function(ctx: TAssignForgeRecipeCandidate)
		return ctx.RecipeExists
	end
)

local RecipeIsAutomatable = Spec.new("RecipeNotAutomatable", Errors.RECIPE_NOT_AUTOMATABLE,
	function(ctx: TAssignForgeRecipeCandidate)
		return ctx.RecipeAutomatable
	end
)

local ForgeRecipeUnlocked = Spec.new("ForgeRecipeLocked", Errors.FORGE_RECIPE_LOCKED,
	function(ctx: TAssignForgeRecipeCandidate)
		return ctx.RecipeUnlocked
	end
)

local RequiredForgeBuilding = Spec.new("ForgeBuildingRequired", Errors.FORGE_BUILDING_REQUIRED,
	function(ctx: TAssignForgeRecipeCandidate)
		return ctx.HasRequiredForgeBuilding
	end
)

-- Brewery recipe assignment

local IsBrewery = Spec.new("WorkerNotBrewery", Errors.WORKER_NOT_BREWERY,
	function(ctx: TAssignBreweryRecipeCandidate)
		return ctx.IsBrewery
	end
)

local BreweryRecipeValid = Spec.new("BreweryRecipeNotFound", Errors.BREWERY_RECIPE_NOT_FOUND,
	function(ctx: TAssignBreweryRecipeCandidate)
		return ctx.RecipeExists
	end
)

local BreweryRecipeIsAutomatable = Spec.new("BreweryRecipeNotAutomatable", Errors.BREWERY_RECIPE_NOT_AUTOMATABLE,
	function(ctx: TAssignBreweryRecipeCandidate)
		return ctx.RecipeAutomatable
	end
)

local BreweryRecipeUnlocked = Spec.new("BreweryRecipeLocked", Errors.BREWERY_RECIPE_LOCKED,
	function(ctx: TAssignBreweryRecipeCandidate)
		return ctx.RecipeUnlocked
	end
)

local RequiredBreweryBuilding = Spec.new("BreweryBuildingRequired", Errors.BREWERY_BUILDING_REQUIRED,
	function(ctx: TAssignBreweryRecipeCandidate)
		return ctx.HasRequiredBreweryBuilding
	end
)

-- Tailoring recipe assignment

local IsTailor = Spec.new("WorkerNotTailor", Errors.WORKER_NOT_TAILOR,
	function(ctx: TAssignTailoringRecipeCandidate)
		return ctx.IsTailor
	end
)

local TailoringRecipeValid = Spec.new("TailoringRecipeNotFound", Errors.TAILORING_RECIPE_NOT_FOUND,
	function(ctx: TAssignTailoringRecipeCandidate)
		return ctx.RecipeExists
	end
)

local TailoringRecipeIsAutomatable = Spec.new("TailoringRecipeNotAutomatable", Errors.TAILORING_RECIPE_NOT_AUTOMATABLE,
	function(ctx: TAssignTailoringRecipeCandidate)
		return ctx.RecipeAutomatable
	end
)

local OreNotAtMaxWorkers = Spec.new("OreAtMaxWorkers", Errors.ORE_AT_MAX_WORKERS,
	function(ctx: TAssignMinerOreCandidate)
		return ctx.WorkersAtOre < ctx.MaxWorkers
	end
)

-- Ore unlock

local OreIsUnlocked = Spec.new("NotUnlocked", Errors.NOT_UNLOCKED,
	function(ctx: TAssignMinerOreCandidate)
		return ctx.IsUnlocked
	end
)

-- Lumberjack target assignment

local IsLumberjack = Spec.new("WorkerNotLumberjack", Errors.WORKER_NOT_LUMBERJACK,
	function(ctx: TAssignLumberjackTargetCandidate)
		return ctx.IsLumberjack
	end
)

local TreeTypeValid = Spec.new("InvalidTreeType", Errors.INVALID_TREE_TYPE,
	function(ctx: TAssignLumberjackTargetCandidate)
		return ctx.TreeTypeExists
	end
)

local LotHasForest = Spec.new("ForestNotFound", Errors.FOREST_NOT_FOUND,
	function(ctx: TAssignLumberjackTargetCandidate)
		return ctx.ForestFolderExists
	end
)

local TreeInLot = Spec.new("TreeNotInLot", Errors.TREE_NOT_IN_LOT,
	function(ctx: TAssignLumberjackTargetCandidate)
		return ctx.TreeInLot
	end
)

local TreeNotAtMaxWorkers = Spec.new("TreeAtMaxWorkers", Errors.TREE_AT_MAX_WORKERS,
	function(ctx: TAssignLumberjackTargetCandidate)
		return ctx.WorkersAtTree < ctx.MaxWorkers
	end
)

-- Herbalist target assignment

local IsHerbalist = Spec.new("WorkerNotHerbalist", Errors.WORKER_NOT_HERBALIST,
	function(ctx: TAssignHerbalistTargetCandidate)
		return ctx.IsHerbalist
	end
)

local PlantTypeValid = Spec.new("InvalidPlantType", Errors.INVALID_PLANT_TYPE,
	function(ctx: TAssignHerbalistTargetCandidate)
		return ctx.PlantTypeExists
	end
)

local LotHasGarden = Spec.new("GardenNotFound", Errors.GARDEN_NOT_FOUND,
	function(ctx: TAssignHerbalistTargetCandidate)
		return ctx.GardenFolderExists
	end
)

local PlantInLot = Spec.new("PlantNotInLot", Errors.PLANT_NOT_IN_LOT,
	function(ctx: TAssignHerbalistTargetCandidate)
		return ctx.PlantInLot
	end
)

local PlantNotAtMaxWorkers = Spec.new("PlantAtMaxWorkers", Errors.PLANT_AT_MAX_WORKERS,
	function(ctx: TAssignHerbalistTargetCandidate)
		return ctx.WorkersAtPlant < ctx.MaxWorkers
	end
)

-- Farmer target assignment

local IsFarmer = Spec.new("WorkerNotFarmer", Errors.WORKER_NOT_FARMER,
	function(ctx: TAssignFarmerTargetCandidate)
		return ctx.IsFarmer
	end
)

local CropTypeValid = Spec.new("InvalidCropType", Errors.INVALID_CROP_TYPE,
	function(ctx: TAssignFarmerTargetCandidate)
		return ctx.CropTypeExists
	end
)

local LotHasFarm = Spec.new("FarmNotFound", Errors.FARM_NOT_FOUND,
	function(ctx: TAssignFarmerTargetCandidate)
		return ctx.FarmFolderExists
	end
)

local CropInLot = Spec.new("CropNotInLot", Errors.CROP_NOT_IN_LOT,
	function(ctx: TAssignFarmerTargetCandidate)
		return ctx.CropInLot
	end
)

local CropNotAtMaxWorkers = Spec.new("CropAtMaxWorkers", Errors.CROP_AT_MAX_WORKERS,
	function(ctx: TAssignFarmerTargetCandidate)
		return ctx.WorkersAtCrop < ctx.MaxWorkers
	end
)

-- Tree unlock

local TreeIsUnlocked = Spec.new("NotUnlocked", Errors.NOT_UNLOCKED,
	function(ctx: TAssignLumberjackTargetCandidate)
		return ctx.IsUnlocked
	end
)

-- Plant unlock

local PlantIsUnlocked = Spec.new("NotUnlocked", Errors.NOT_UNLOCKED,
	function(ctx: TAssignHerbalistTargetCandidate)
		return ctx.IsUnlocked
	end
)

-- Crop unlock

local CropIsUnlocked = Spec.new("NotUnlocked", Errors.NOT_UNLOCKED,
	function(ctx: TAssignFarmerTargetCandidate)
		return ctx.IsUnlocked
	end
)

return table.freeze({
	CanHire                   = WorkerTypeValid,
	CanAssignRole             = WorkerExists:And(Spec.All({ RoleValid, RoleIsUnlocked })),
	CanAssignMinerOre         = WorkerExists:And(Spec.All({ IsMiner, OreTypeValid, LotHasMines, OreInLot, OreNotAtMaxWorkers, OreIsUnlocked })),
	CanAssignForgeRecipe      = WorkerExists:And(
		Spec.All({ IsForge, RecipeValid, RecipeIsAutomatable, ForgeRecipeUnlocked, RequiredForgeBuilding })
	),
	CanAssignBreweryRecipe    = WorkerExists:And(Spec.All({ IsBrewery, BreweryRecipeValid, BreweryRecipeIsAutomatable, BreweryRecipeUnlocked, RequiredBreweryBuilding })),
	CanAssignTailoringRecipe  = WorkerExists:And(Spec.All({ IsTailor, TailoringRecipeValid, TailoringRecipeIsAutomatable })),
	CanAssignLumberjackTarget = WorkerExists:And(Spec.All({ IsLumberjack, TreeTypeValid, LotHasForest, TreeInLot, TreeNotAtMaxWorkers, TreeIsUnlocked })),
	CanAssignHerbalistTarget  = WorkerExists:And(Spec.All({ IsHerbalist, PlantTypeValid, LotHasGarden, PlantInLot, PlantNotAtMaxWorkers, PlantIsUnlocked })),
	CanAssignFarmerTarget     = WorkerExists:And(Spec.All({ IsFarmer, CropTypeValid, LotHasFarm, CropInLot, CropNotAtMaxWorkers, CropIsUnlocked })),
})
