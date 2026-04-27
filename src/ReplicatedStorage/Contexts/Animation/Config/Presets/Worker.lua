--!strict

local Constants = require(script.Parent.Parent.AnimationPresetConstants)

return table.freeze({
	Id = "Worker",
	Tag = "[AnimateWorker]",
	VariantAttribute = "Occupation",
	DefaultVariant = "Default",
	ReloadOnVariantChanged = true,
	CorePoseFolders = Constants.FULL_CORE_POSE_FOLDERS,
	AllPoses = Constants.ALL_POSES,
	PoseFallbacks = Constants.FULL_POSE_FALLBACKS,
	WarnOnMissingPose = true,
	WarnOnMissingAnimation = true,
})
