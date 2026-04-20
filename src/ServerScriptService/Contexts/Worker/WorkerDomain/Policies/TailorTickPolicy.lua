--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TailoringRecipeConfig = require(ReplicatedStorage.Contexts.Tailoring.Config.TailoringRecipeConfig)
local WorkerSpecs = require(script.Parent.Parent.Specs.WorkerSpecs)

local BaseRecipeTickPolicy = require(script.Parent.Shared.BaseRecipeTickPolicy)

local TailorTickPolicy = {}
TailorTickPolicy.__index = TailorTickPolicy

function TailorTickPolicy.new()
	return BaseRecipeTickPolicy.new({
		RecipeConfigTable = TailoringRecipeConfig,
		Spec = WorkerSpecs.CanTailorThisTick,
		BuildCandidate = function(ctx: BaseRecipeTickPolicy.TRecipeTickPolicyCheckContext): WorkerSpecs.TTailoringTickCandidate
			return {
				HasRecipeAssigned = ctx.HasRecipeAssigned,
				HasIngredients = ctx.HasIngredients,
			}
		end,
	})
end

return TailorTickPolicy
