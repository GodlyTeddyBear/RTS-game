--!strict

local Helpers = require(script.Parent.Parent.AnimationPresetHelpers)
local Constants = require(script.Parent.Parent.AnimationPresetConstants)

return table.freeze({
	Id = "Player",
	Tag = "[AnimatePlayer]",
	DefaultVariant = "Default",
	CorePoseFolders = Constants.FULL_CORE_POSE_FOLDERS,
	AllPoses = Constants.ALL_POSES,
	PoseFallbacks = Constants.FULL_POSE_FALLBACKS,
	EnableEmotes = true,
	EmoteFolders = Constants.EMOTE_FOLDERS,
	WarnOnMissingPose = true,
	WarnOnMissingAnimation = true,
	ActionNameTransform = Helpers.ToActionName,
})
