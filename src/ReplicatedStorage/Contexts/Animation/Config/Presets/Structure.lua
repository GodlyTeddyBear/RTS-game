--!strict

local Helpers = require(script.Parent.Parent.AnimationPresetHelpers)
local Constants = require(script.Parent.Parent.AnimationPresetConstants)

local ACTION_STATE_FALLBACKS = table.freeze({
	StructureAttack = "Attack",
	StructureExtract = "Extract",
})

return table.freeze({
	Id = "Structure",
	Tag = "[AnimateStructure]",
	VariantAttribute = "StructureType",
	DefaultVariant = "Default",
	ReloadOnVariantChanged = true,
	CorePoseFolders = Constants.STRUCTURE_CORE_POSE_FOLDERS,
	AllPoses = Constants.ALL_POSES,
	PoseFallbacks = {},
	PoseFilterMode = "Whitelist",
	PoseFilter = Helpers.BuildSet({ "Idle" }),
	WarnOnMissingPose = true,
	WarnOnMissingAnimation = true,
	ActionNameTransform = Helpers.ToActionName,
	ActionStateFallback = function(state: string, validActions: { [string]: boolean }): string?
		local actionName = ACTION_STATE_FALLBACKS[state]
		return if actionName ~= nil and validActions[actionName] then actionName else nil
	end,
})
