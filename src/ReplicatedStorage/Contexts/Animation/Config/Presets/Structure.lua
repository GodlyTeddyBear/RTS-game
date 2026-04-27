--!strict

local Helpers = require(script.Parent.Parent.AnimationPresetHelpers)
local Constants = require(script.Parent.Parent.AnimationPresetConstants)

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
		if state ~= "StructureAttack" then
			return nil
		end
		if validActions.Attack then
			return "Attack"
		end
		return nil
	end,
})
