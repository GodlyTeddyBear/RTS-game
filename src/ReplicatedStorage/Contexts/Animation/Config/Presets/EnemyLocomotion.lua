--!strict

local Helpers = require(script.Parent.Parent.AnimationPresetHelpers)
local Constants = require(script.Parent.Parent.AnimationPresetConstants)

local ACTION_STATE_CANDIDATES = table.freeze({
	Attack = table.freeze({ "AttackStructure", "attackstructure", "AttackBase", "attackbase" }),
	AttackBase = table.freeze({ "AttackStructure", "attackstructure", "Attack", "attack" }),
	AttackStructure = table.freeze({ "Attack", "attack" }),
})

return table.freeze({
	Id = "EnemyLocomotion",
	Tag = "[AnimateEnemy]",
	ReplicatedStateMode = "ActionOnly",
	VariantAttribute = "EntityDefinitionId",
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

		local candidates = ACTION_STATE_CANDIDATES[state]
		if candidates == nil then
			return nil
		end

		for _, candidate in ipairs(candidates) do
			if validActions[candidate] then
				return candidate
			end
		end

		return nil
	end,
})
