--!strict

local AnimationPresetConstants = {
	FULL_CORE_POSE_FOLDERS = table.freeze({
		{ Folder = "idle", Pose = "Idle" },
		{ Folder = "walk", Pose = "Walk" },
		{ Folder = "run", Pose = "Run" },
		{ Folder = "fall", Pose = "Freefall" },
		{ Folder = "climb", Pose = "Climbing" },
		{ Folder = "sit", Pose = "Seated" },
		{ Folder = "jump", Pose = "Jumping" },
	}),
	COMBAT_CORE_POSE_FOLDERS = table.freeze({
		{ Folder = "idle", Pose = "Idle" },
		{ Folder = "walk", Pose = "Walk" },
		{ Folder = "run", Pose = "Run" },
	}),
	ENEMY_LOCOMOTION_CORE_POSE_FOLDERS = table.freeze({
		{ Folder = "idle", Pose = "Idle" },
		{ Folder = "walk", Pose = "Walk" },
		{ Folder = "run", Pose = "Run" },
	}),
	STRUCTURE_CORE_POSE_FOLDERS = table.freeze({
		{ Folder = "idle", Pose = "Idle" },
	}),
	ALL_POSES = table.freeze({
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
	}),
	FULL_POSE_FALLBACKS = table.freeze({
		GettingUp = "Idle",
		FallingDown = "Freefall",
		Landed = "Idle",
		FellOff = "Freefall",
		Swimming = "Walk",
		SwimIdle = "Idle",
	}),
	COMBAT_POSE_FALLBACKS = table.freeze({
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
	}),
	ENEMY_LOCOMOTION_POSE_FALLBACKS = table.freeze({
		Run = "Walk",
	}),
	EMOTE_FOLDERS = table.freeze({
		dance = true,
		dance2 = true,
		dance3 = true,
		wave = true,
		point = true,
		laugh = true,
		cheer = true,
	}),
}

return table.freeze(AnimationPresetConstants)
