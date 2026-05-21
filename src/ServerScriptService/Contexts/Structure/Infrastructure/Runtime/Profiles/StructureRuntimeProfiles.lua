--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local BehaviorConfig = require(ReplicatedStorage.Contexts.Combat.Config.BehaviorConfig)
local StructureConfig = require(ReplicatedStorage.Contexts.Structure.Config.StructureConfig)
local StructureTypes = require(ReplicatedStorage.Contexts.Structure.Types.StructureTypes)
local BaseRuntimeProfileModule = require(ServerStorage.Utilities.ECSUtilities.BaseRuntimeProfileModule)
local StructureBehavior = require(script.Parent.Parent.Parent.BehaviorSystem.Behaviors.StructureBehavior)
local ExtractorBehavior = require(script.Parent.Parent.Parent.BehaviorSystem.Behaviors.ExtractorBehavior)
local StasisBehavior = require(script.Parent.Parent.Parent.BehaviorSystem.Behaviors.StasisBehavior)

type StructureType = StructureTypes.StructureType
type TStructureConfig = StructureTypes.TStructureConfig

local StructureAttackAnimationMap = {
	["Structure.Attack"] = {
		Running = "StructureAttack",
		Committed = "StructureAttack",
	},
}

local StructureExtractAnimationMap = {
	["Structure.Extract"] = {
		Running = "StructureExtract",
		Committed = "StructureExtract",
	},
}

local StructureAttackLoopingMap = {
	Idle = true,
	StructureAttack = false,
}

local StructureExtractLoopingMap = {
	Idle = true,
	StructureExtract = true,
}

local StructurePassiveLoopingMap = {
	Idle = true,
}

local function _ResolveVariantIdForStructureType(structureType: StructureType?): string?
	if type(structureType) ~= "string" then
		return nil
	end

	local structureConfig = StructureConfig.STRUCTURES[structureType] :: TStructureConfig?
	assert(
		structureConfig ~= nil,
		("StructureRuntimeProfiles: missing config for structure type '%s'"):format(tostring(structureType))
	)
	return structureConfig.RuntimeProfileId
end

local BaseProfiles = BaseRuntimeProfileModule.new({
	Label = "StructureRuntimeProfiles",
	ProfilesByVariant = {
		Attack = BaseRuntimeProfileModule.CreateProfile({
			VariantId = "Attack",
			BehaviorDefinition = StructureBehavior,
			DefaultAnimationState = "Idle",
			AnimationByActionIdAndState = StructureAttackAnimationMap,
			LoopingByAnimationState = StructureAttackLoopingMap,
			TickInterval = BehaviorConfig.DEFAULT.TickInterval,
		}),
		Extract = BaseRuntimeProfileModule.CreateProfile({
			VariantId = "Extract",
			BehaviorDefinition = ExtractorBehavior,
			DefaultAnimationState = "Idle",
			AnimationByActionIdAndState = StructureExtractAnimationMap,
			LoopingByAnimationState = StructureExtractLoopingMap,
			TickInterval = BehaviorConfig.DEFAULT.TickInterval,
		}),
		Passive = BaseRuntimeProfileModule.CreateProfile({
			VariantId = "Passive",
			BehaviorDefinition = ExtractorBehavior,
			DefaultAnimationState = "Idle",
			AnimationByActionIdAndState = {},
			LoopingByAnimationState = StructurePassiveLoopingMap,
			TickInterval = BehaviorConfig.DEFAULT.TickInterval,
		}),
		Stasis = BaseRuntimeProfileModule.CreateProfile({
			VariantId = "Stasis",
			BehaviorDefinition = StasisBehavior,
			DefaultAnimationState = "Idle",
			AnimationByActionIdAndState = {},
			LoopingByAnimationState = StructurePassiveLoopingMap,
			TickInterval = BehaviorConfig.DEFAULT.TickInterval,
		}),
	},
	ResolveVariantId = function(input: {
		VariantId: string?,
		StructureType: StructureType?,
		CombatAction: any,
	}): string?
		if type(input.VariantId) == "string" and input.VariantId ~= "" then
			return input.VariantId
		end
		return _ResolveVariantIdForStructureType(input.StructureType)
	end,
})

local StructureRuntimeProfiles = {}

function StructureRuntimeProfiles.GetByVariant(variantId: string)
	return BaseProfiles:GetByVariant(variantId)
end

function StructureRuntimeProfiles.ResolveAnimationState(input: {
	VariantId: string?,
	StructureType: StructureType?,
	CombatAction: any,
}): (string, boolean)
	return BaseProfiles:ResolveAnimationState(input)
end

return table.freeze(StructureRuntimeProfiles)
