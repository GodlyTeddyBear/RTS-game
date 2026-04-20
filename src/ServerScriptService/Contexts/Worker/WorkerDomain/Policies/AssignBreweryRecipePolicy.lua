--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local BreweryRecipeConfig = require(ReplicatedStorage.Contexts.Brewery.Config.BreweryRecipeConfig)
local BreweryStationConfig = require(ReplicatedStorage.Contexts.Brewery.Config.BreweryStationConfig)
local WorkerSpecs = require(script.Parent.Parent.Specs.WorkerSpecs)

local BaseAssignRecipePolicy = require(script.Parent.Shared.BaseAssignRecipePolicy)

local AssignBreweryRecipePolicy = {}
AssignBreweryRecipePolicy.__index = AssignBreweryRecipePolicy

local function resolveStationInstance(lotContext: any, userId: number, buildingType: string): Instance?
	if not lotContext then
		return nil
	end

	local breweryFolder = lotContext:GetBreweryFolderForUser(userId)
	if not breweryFolder then
		return nil
	end

	for _, child in breweryFolder:GetChildren() do
		if child:IsA("Model") and child.Name == buildingType then
			return child
		end
	end

	-- Fallback to the first slot anchor so workers still get deterministic placement when model names differ.
	for _, child in breweryFolder:GetChildren() do
		if child:IsA("BasePart") and string.find(child.Name, "BuildSlot_") == 1 then
			return child
		end
	end

	return nil
end

function AssignBreweryRecipePolicy.new()
	return BaseAssignRecipePolicy.new({
		RecipeConfigTable = BreweryRecipeConfig,
		Spec = WorkerSpecs.CanAssignBreweryRecipe,
		PolicyUsesUserId = true,
		BuildCandidate = function(ctx: BaseAssignRecipePolicy.TRecipePolicyCheckContext): WorkerSpecs.TAssignBreweryRecipeCandidate
			local recipe = ctx.Recipe
			local stationInfo = recipe and recipe.BrewStation and BreweryStationConfig[recipe.BrewStation] or nil
			local requiredBuildingType = stationInfo and stationInfo.BuildingType
			local hasRequiredBuilding = false
			local isUnlocked = false

			if recipe and ctx.UserId and ctx.UnlockContext and ctx.BuildingContext and requiredBuildingType then
				isUnlocked = ctx.UnlockContext:IsUnlocked(ctx.UserId, ctx.RecipeId)
				hasRequiredBuilding = ctx.BuildingContext:HasBuildingForUser(ctx.UserId, "Brewery", requiredBuildingType)
			end

			return {
				Entity = ctx.Entity,
				IsBrewery = ctx.Assignment ~= nil and ctx.Assignment.Role == "Brewery",
				RecipeExists = recipe ~= nil,
				RecipeAutomatable = recipe ~= nil and recipe.IsAutomatable == true,
				RecipeUnlocked = recipe == nil or isUnlocked,
				HasRequiredBreweryBuilding = recipe == nil or hasRequiredBuilding,
			}
		end,
		BuildResult = function(ctx: BaseAssignRecipePolicy.TRecipePolicyCheckContext)
			local recipe = ctx.Recipe
			local stationInfo = recipe and recipe.BrewStation and BreweryStationConfig[recipe.BrewStation] or nil
			local buildingType = stationInfo and stationInfo.BuildingType or "BrewKettle"
			local stationInstance = nil
			if ctx.UserId and ctx.LotContext then
				stationInstance = resolveStationInstance(ctx.LotContext, ctx.UserId, buildingType)
			end
			return {
				BreweryStationInstance = stationInstance,
				SlotTargetId = `BreweryStation_{buildingType}`,
			}
		end,
	})
end

return AssignBreweryRecipePolicy
