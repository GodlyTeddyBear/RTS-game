--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local StructureConfig = require(ReplicatedStorage.Contexts.Structure.Config.StructureConfig)
local StructureTypes = require(ReplicatedStorage.Contexts.Structure.Types.StructureTypes)
local StructureBehavior = require(script.Parent.Parent.BehaviorSystem.Behaviors.StructureBehavior)
local ExtractorBehavior = require(script.Parent.Parent.BehaviorSystem.Behaviors.ExtractorBehavior)

type StructureType = StructureTypes.StructureType
type TStructureConfig = StructureTypes.TStructureConfig

type TAnimationStateMap = {
	[string]: {
		[string]: string,
	},
}

type TLoopingStateMap = {
	[string]: boolean,
}

export type TStructureRuntimeProfile = {
	BehaviorDefinition: any,
	DefaultAnimationState: string,
	AnimationByActionIdAndState: TAnimationStateMap,
	LoopingByAnimationState: TLoopingStateMap,
}

local PROFILES_BY_BEHAVIOR_ID: { [string]: TStructureRuntimeProfile } = table.freeze({
	Attack = table.freeze({
		BehaviorDefinition = StructureBehavior,
		DefaultAnimationState = "Idle",
		AnimationByActionIdAndState = table.freeze({
			["Structure.Attack"] = table.freeze({
				Running = "StructureAttack",
				Committed = "StructureAttack",
			}),
		}),
		LoopingByAnimationState = table.freeze({
			Idle = true,
			StructureAttack = false,
		}),
	}),
	Extract = table.freeze({
		BehaviorDefinition = ExtractorBehavior,
		DefaultAnimationState = "Idle",
		AnimationByActionIdAndState = table.freeze({
			["Structure.Extract"] = table.freeze({
				Running = "StructureExtract",
				Committed = "StructureExtract",
			}),
		}),
		LoopingByAnimationState = table.freeze({
			Idle = true,
			StructureExtract = true,
		}),
	}),
})

local StructureRuntimeProfileRegistry = {}

function StructureRuntimeProfileRegistry.GetByBehaviorId(behaviorId: string): TStructureRuntimeProfile
	local profile = PROFILES_BY_BEHAVIOR_ID[behaviorId]
	assert(
		profile ~= nil,
		("StructureRuntimeProfileRegistry: unknown behavior id '%s'"):format(tostring(behaviorId))
	)
	return profile
end

function StructureRuntimeProfileRegistry.GetByStructureType(structureType: StructureType): TStructureRuntimeProfile
	local structureConfig = StructureConfig.STRUCTURES[structureType] :: TStructureConfig?
	assert(
		structureConfig ~= nil,
		("StructureRuntimeProfileRegistry: missing config for structure type '%s'"):format(tostring(structureType))
	)

	return StructureRuntimeProfileRegistry.GetByBehaviorId(structureConfig.BehaviorId)
end

return table.freeze(StructureRuntimeProfileRegistry)
