--!strict

local AnimationClipLoader = require(script.Parent.AnimationClipLoader)

local FULL_CORE_POSE_FOLDERS = {
	{ Folder = "idle", Pose = "Idle" },
	{ Folder = "walk", Pose = "Walk" },
	{ Folder = "run", Pose = "Run" },
	{ Folder = "fall", Pose = "Freefall" },
	{ Folder = "climb", Pose = "Climbing" },
	{ Folder = "sit", Pose = "Seated" },
	{ Folder = "jump", Pose = "Jumping" },
}

local COMBAT_CORE_POSE_FOLDERS = {
	{ Folder = "idle", Pose = "Idle" },
	{ Folder = "walk", Pose = "Walk" },
	{ Folder = "run", Pose = "Run" },
}

local ENEMY_LOCOMOTION_CORE_POSE_FOLDERS = {
	{ Folder = "idle", Pose = "Idle" },
	{ Folder = "walk", Pose = "Walk" },
	{ Folder = "run", Pose = "Run" },
}

local STRUCTURE_CORE_POSE_FOLDERS = {
	{ Folder = "idle", Pose = "Idle" },
}

local ALL_POSES = {
	"Run",
	"Idle",
	"Walk",
	"GettingUp",
	"FallingDown",
	"Freefall",
	"FellOff",
	"Jumping",
	"Landed",
	"Seated",
	"Swimming",
	"Climbing",
	"SwimIdle",
}

local FULL_POSE_FALLBACKS = {
	GettingUp = "Idle",
	FallingDown = "Freefall",
	Landed = "Idle",
	FellOff = "Freefall",
	Swimming = "Walk",
	SwimIdle = "Idle",
}

local COMBAT_POSE_FALLBACKS = {
	Run = "Walk",
	GettingUp = "Idle",
	FallingDown = "Idle",
	Freefall = "Idle",
	FellOff = "Idle",
	Jumping = "Idle",
	Landed = "Idle",
	Seated = "Idle",
	Swimming = "Walk",
	SwimIdle = "Idle",
	Climbing = "Walk",
}

local ENEMY_LOCOMOTION_POSES = {
	"Idle",
	"Walk",
	"Run",
}

local STRUCTURE_POSES = {
	"Idle",
}

local ENEMY_LOCOMOTION_POSE_FALLBACKS = {
	Run = "Walk",
}

local EMOTE_FOLDERS = {
	dance = true,
	dance2 = true,
	dance3 = true,
	wave = true,
	point = true,
	laugh = true,
	cheer = true,
}

local AnimationPresets = {}

function AnimationPresets.Player(animationsFolder: Folder)
	return {
		Tag = "[AnimatePlayer]",
		AnimationsFolder = animationsFolder,
		UseDirectAnimationsFolder = true,
		DefaultVariant = "Default",
		CorePoseFolders = FULL_CORE_POSE_FOLDERS,
		AllPoses = ALL_POSES,
		PoseFallbacks = FULL_POSE_FALLBACKS,
		EnableEmotes = true,
		EmoteFolders = EMOTE_FOLDERS,
		WarnOnMissingPose = true,
		WarnOnMissingAnimation = true,
		ActionNameTransform = AnimationClipLoader.ToActionName,
	}
end

AnimationPresets.Worker = {
	Tag = "[AnimateWorker]",
	VariantAttribute = "Occupation",
	DefaultVariant = "Default",
	ReloadOnVariantChanged = true,
	CorePoseFolders = FULL_CORE_POSE_FOLDERS,
	AllPoses = ALL_POSES,
	PoseFallbacks = FULL_POSE_FALLBACKS,
	WarnOnMissingPose = true,
	WarnOnMissingAnimation = true,
}

AnimationPresets.CombatNPC = {
	Tag = "[AnimateCombatNPC]",
	VariantAttribute = "NPCType",
	DefaultVariant = "Default",
	CorePoseFolders = COMBAT_CORE_POSE_FOLDERS,
	AllPoses = ALL_POSES,
	PoseFallbacks = COMBAT_POSE_FALLBACKS,
	ActionNameTransform = AnimationClipLoader.ToActionName,
	ActionStateFallback = function(state: string, validActions: { [string]: boolean }): string?
		if validActions[state] then
			return nil
		end
		if validActions.Attack then
			return "Attack"
		end
		return nil
	end,
}

AnimationPresets.EnemyLocomotion = {
	Tag = "[AnimateEnemy]",
	VariantAttribute = "EnemyRole",
	DefaultVariant = "Default",
	ReloadOnVariantChanged = true,
	CorePoseFolders = ENEMY_LOCOMOTION_CORE_POSE_FOLDERS,
	AllPoses = ENEMY_LOCOMOTION_POSES,
	PoseFallbacks = ENEMY_LOCOMOTION_POSE_FALLBACKS,
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
}

AnimationPresets.Structure = {
	Tag = "[AnimateStructure]",
	DefaultVariant = "Default",
	CorePoseFolders = STRUCTURE_CORE_POSE_FOLDERS,
	AllPoses = STRUCTURE_POSES,
	PoseFallbacks = {},
	WarnOnMissingPose = true,
	WarnOnMissingAnimation = true,
	ActionNameTransform = AnimationClipLoader.ToActionName,
	ActionStateFallback = function(state: string, validActions: { [string]: boolean }): string?
		if state ~= "StructureAttack" then
			return nil
		end
		if validActions.Attack then
			return "Attack"
		end
		return nil
	end,
}

return AnimationPresets
