--!strict

local Helpers = require(script.Parent.Parent.AnimationPresetHelpers)
local Constants = require(script.Parent.Parent.AnimationPresetConstants)

local ACTION_STATE_FALLBACKS = table.freeze({
	AttackBase = "Attack",
	AttackStructure = "Attack",
})

return table.freeze({
	Id = "CombatNPC",
	Tag = "[AnimateCombatNPC]",
	ReplicatedStateMode = "ActionOnly",
	VariantAttribute = "EntityDefinitionId",
	DefaultVariant = "Default",
	CorePoseFolders = Constants.COMBAT_CORE_POSE_FOLDERS,
	AllPoses = Constants.ALL_POSES,
	PoseFallbacks = Constants.COMBAT_POSE_FALLBACKS,
	WarnOnMissingPose = true,
	WarnOnMissingAnimation = true,
	ActionNameTransform = Helpers.ToActionName,
	ActionStateFallback = function(state: string, validActions: { [string]: boolean }): string?
		if validActions[state] then
			return nil
		end
		local fallback = ACTION_STATE_FALLBACKS[state]
		return if fallback ~= nil and validActions[fallback] then fallback else nil
	end,
})
