--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local BehaviorConfig = require(ReplicatedStorage.Contexts.Combat.Config.BehaviorConfig)
local BaseRuntimeProfileModule = require(ServerStorage.Utilities.ECSUtilities.BaseRuntimeProfileModule)
local UnitBuilderBehavior = require(script.Parent.Parent.Parent.BehaviorSystem.Behaviors.UnitBuilderBehavior)

local BaseProfiles = BaseRuntimeProfileModule.new({
	Label = "UnitRuntimeProfiles",
	ProfilesByVariant = {
		Builder = BaseRuntimeProfileModule.CreateProfile({
			VariantId = "Builder",
			BehaviorDefinition = UnitBuilderBehavior,
			DefaultAnimationState = "Idle",
			AnimationByActionIdAndState = {},
			LoopingByAnimationState = {
				Idle = true,
			},
			TickInterval = BehaviorConfig.DEFAULT.TickInterval,
		}),
	},
	ResolveVariantId = function(input: {
		VariantId: string?,
		CombatAction: any,
	}): string?
		if type(input.VariantId) == "string" and input.VariantId ~= "" then
			return input.VariantId
		end
		return nil
	end,
})

local UnitRuntimeProfiles = {}

function UnitRuntimeProfiles.GetByVariant(variantId: string)
	return BaseProfiles:GetByVariant(variantId)
end

function UnitRuntimeProfiles.ResolveAnimationState(input: {
	VariantId: string?,
	CombatAction: any,
}): (string, boolean)
	return BaseProfiles:ResolveAnimationState(input)
end

return table.freeze(UnitRuntimeProfiles)
