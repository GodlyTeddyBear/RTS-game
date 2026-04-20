--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TailoringRecipeConfig = require(ReplicatedStorage.Contexts.Tailoring.Config.TailoringRecipeConfig)
local WorkerSpecs = require(script.Parent.Parent.Specs.WorkerSpecs)

local BaseAssignRecipePolicy = require(script.Parent.Shared.BaseAssignRecipePolicy)

local AssignTailoringRecipePolicy = {}
AssignTailoringRecipePolicy.__index = AssignTailoringRecipePolicy

function AssignTailoringRecipePolicy.new()
	return BaseAssignRecipePolicy.new({
		RecipeConfigTable = TailoringRecipeConfig,
		Spec = WorkerSpecs.CanAssignTailoringRecipe,
		BuildCandidate = function(ctx: BaseAssignRecipePolicy.TRecipePolicyCheckContext): WorkerSpecs.TAssignTailoringRecipeCandidate
			return {
				Entity = ctx.Entity,
				IsTailor = ctx.Assignment ~= nil and ctx.Assignment.Role == "Tailor",
				RecipeExists = ctx.Recipe ~= nil,
				RecipeAutomatable = ctx.Recipe ~= nil and ctx.Recipe.IsAutomatable == true,
			}
		end,
	})
end

return AssignTailoringRecipePolicy
