--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RecipeConfig = require(ReplicatedStorage.Contexts.Forge.Config.RecipeConfig)
local ForgeStationConfig = require(ReplicatedStorage.Contexts.Forge.Config.ForgeStationConfig)
local WorkerSpecs = require(script.Parent.Parent.Specs.WorkerSpecs)

local BaseAssignRecipePolicy = require(script.Parent.Shared.BaseAssignRecipePolicy)

local AssignForgeRecipePolicy = {}
AssignForgeRecipePolicy.__index = AssignForgeRecipePolicy

local function resolveStationInstance(lotContext: any, userId: number, buildingType: string): Instance?
	if not lotContext then
		return nil
	end

	local forgeFolder = lotContext:GetForgeFolderForUser(userId)
	if not forgeFolder then
		return nil
	end

	for _, child in forgeFolder:GetChildren() do
		if child:IsA("Model") and child.Name == buildingType then
			return child
		end
	end

	-- Fallback to the first slot anchor so workers still get deterministic placement when model names differ.
	for _, child in forgeFolder:GetChildren() do
		if child:IsA("BasePart") and string.find(child.Name, "BuildSlot_") == 1 then
			return child
		end
	end

	return nil
end

function AssignForgeRecipePolicy.new()
	return BaseAssignRecipePolicy.new({
		RecipeConfigTable = RecipeConfig,
		Spec = WorkerSpecs.CanAssignForgeRecipe,
		PolicyUsesUserId = true,
		BuildCandidate = function(ctx: BaseAssignRecipePolicy.TRecipePolicyCheckContext): WorkerSpecs.TAssignForgeRecipeCandidate
			local recipe = ctx.Recipe
			local stationInfo = recipe and ForgeStationConfig[recipe.ForgeStation] or nil
			local requiredBuildingType = stationInfo and stationInfo.BuildingType
			local hasRequiredBuilding = false
			local isUnlocked = false

			if recipe and ctx.UserId and ctx.UnlockContext and ctx.BuildingContext and requiredBuildingType then
				isUnlocked = ctx.UnlockContext:IsUnlocked(ctx.UserId, ctx.RecipeId)
				hasRequiredBuilding = ctx.BuildingContext:HasBuildingForUser(ctx.UserId, "Forge", requiredBuildingType)
			end

			return {
				Entity = ctx.Entity,
				IsForge = ctx.Assignment ~= nil and ctx.Assignment.Role == "Forge",
				RecipeExists = recipe ~= nil,
				RecipeAutomatable = recipe ~= nil and recipe.IsAutomatable == true,
				RecipeUnlocked = recipe == nil or isUnlocked,
				HasRequiredForgeBuilding = recipe == nil or hasRequiredBuilding,
			}
		end,
		BuildResult = function(ctx: BaseAssignRecipePolicy.TRecipePolicyCheckContext)
			local recipe = ctx.Recipe
			local stationInfo = recipe and ForgeStationConfig[recipe.ForgeStation] or nil
			local buildingType = stationInfo and stationInfo.BuildingType or "Anvil"
			local stationInstance = nil
			if ctx.UserId and ctx.LotContext then
				stationInstance = resolveStationInstance(ctx.LotContext, ctx.UserId, buildingType)
			end
			return {
				ForgeStationInstance = stationInstance,
				SlotTargetId = `ForgeStation_{buildingType}`,
			}
		end,
	})
end

return AssignForgeRecipePolicy
