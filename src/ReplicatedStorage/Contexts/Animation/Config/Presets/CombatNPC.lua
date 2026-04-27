--!strict

local Helpers = require(script.Parent.Parent.AnimationPresetHelpers)
local Constants = require(script.Parent.Parent.AnimationPresetConstants)

return table.freeze({
	Id = "CombatNPC",
	Tag = "[AnimateCombatNPC]",
	VariantAttribute = "NPCType",
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
		if validActions.Attack then
			return "Attack"
		end
		return nil
	end,
})
