--!strict

local Helpers = require(script.Parent.Parent.AnimationPresetHelpers)
local Constants = require(script.Parent.Parent.AnimationPresetConstants)

return table.freeze({
	Id = "EnemyLocomotion",
	Tag = "[AnimateEnemy]",
	VariantAttribute = "EnemyRole",
	DefaultVariant = "Default",
	ReloadOnVariantChanged = true,
	CorePoseFolders = Constants.ENEMY_LOCOMOTION_CORE_POSE_FOLDERS,
	AllPoses = Constants.ALL_POSES,
	PoseFallbacks = Constants.ENEMY_LOCOMOTION_POSE_FALLBACKS,
	PoseFilterMode = "Whitelist",
	PoseFilter = Helpers.BuildSet({ "Idle", "Walk", "Run" }),
	WarnOnMissingPose = true,
	WarnOnMissingAnimation = true,
	UseStateDrivenCorePoses = true,
	ActionStateFallback = function(state: string, validActions: { [string]: boolean }): string?
		if validActions[state] then
			return nil
		end
		if state == "AttackBase" and validActions.AttackStructure then
			return "AttackStructure"
		end
		if state == "AttackBase" and validActions.attackstructure then
			return "attackstructure"
		end
		if (state == "AttackBase" or state == "AttackStructure") and validActions.Attack then
			return "Attack"
		end
		if (state == "AttackBase" or state == "AttackStructure") and validActions.attack then
			return "attack"
		end
		return nil
	end,
})
