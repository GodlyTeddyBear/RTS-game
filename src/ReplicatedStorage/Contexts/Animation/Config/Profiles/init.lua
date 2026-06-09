--!strict

local Types = require(script.Parent.Parent.Types.AnimationTypes)

type TAnimationProfile = Types.TAnimationProfile

local function _Channel(
	channelId: string,
	slotId: string,
	priority: Enum.AnimationPriority,
	looped: boolean,
	options: any?
): Types.TAnimationChannelPolicy
	local resolvedOptions = options or {}
	return table.freeze({
		ChannelId = channelId,
		SlotId = slotId,
		Priority = priority,
		InterruptPriority = resolvedOptions.InterruptPriority or 0,
		FadeIn = resolvedOptions.FadeIn or 0.1,
		FadeOut = resolvedOptions.FadeOut or 0.1,
		Looped = looped,
		SuppressLocomotion = resolvedOptions.SuppressLocomotion == true,
		AllowLocalRequests = resolvedOptions.AllowLocalRequests == true,
	})
end

local HUMANOID_CORE_POSE_SLOTS = table.freeze({
	Idle = "Idle",
	Walk = "Walk",
	Run = "Run",
	Jumping = "Jump",
	Freefall = "Fall",
	Climbing = "Climb",
	Seated = "Sit",
})

local HUMANOID_CORE_POSE_FALLBACKS = table.freeze({
	GettingUp = "Idle",
	FallingDown = "Freefall",
	FellOff = "Freefall",
	Landed = "Idle",
	Swimming = "Walk",
	SwimIdle = "Idle",
})

local COMMON_HUMANOID_CHANNELS = table.freeze({
	FullBody = _Channel("FullBody", "FullBodyAction", Enum.AnimationPriority.Action, false, {
		InterruptPriority = 100,
		SuppressLocomotion = true,
	}),
	UpperBody = _Channel("UpperBody", "Action", Enum.AnimationPriority.Action, false, {
		InterruptPriority = 50,
	}),
	Emote = _Channel("Emote", "Emote", Enum.AnimationPriority.Action, false, {
		AllowLocalRequests = true,
		InterruptPriority = 10,
		SuppressLocomotion = true,
	}),
})

local Profiles: { [string]: TAnimationProfile } = {
	PlayerHumanoid = table.freeze({
		Id = "PlayerHumanoid",
		RigAdapter = "Auto",
		LocomotionProvider = "HumanoidState",
		DefaultSetId = "Player",
		RequiredSlots = table.freeze({ "Idle", "Walk" }),
		OptionalSlots = table.freeze({ "Run", "Jump", "Fall", "Climb", "Sit", "Emote" }),
		CorePoseSlots = HUMANOID_CORE_POSE_SLOTS,
		CorePoseFallbacks = HUMANOID_CORE_POSE_FALLBACKS,
		Channels = COMMON_HUMANOID_CHANNELS,
		Features = table.freeze({
			Lean = table.freeze({
				Enabled = true,
			}),
		}),
		DisableDefaultAnimate = true,
		RootMotionEnabled = false,
	}),
	HumanoidCombat = table.freeze({
		Id = "HumanoidCombat",
		RigAdapter = "Auto",
		LocomotionProvider = "HumanoidState",
		DefaultSetId = "CombatNPC",
		RequiredSlots = table.freeze({ "Idle", "Walk" }),
		OptionalSlots = table.freeze({ "Run", "Attack", "Build", "Extract", "Stasis" }),
		CorePoseSlots = HUMANOID_CORE_POSE_SLOTS,
		CorePoseFallbacks = HUMANOID_CORE_POSE_FALLBACKS,
		Channels = COMMON_HUMANOID_CHANNELS,
		Features = table.freeze({
			Lean = table.freeze({
				Enabled = true,
			}),
		}),
		DisableDefaultAnimate = true,
		RootMotionEnabled = false,
	}),
	StructureActor = table.freeze({
		Id = "StructureActor",
		RigAdapter = "Auto",
		LocomotionProvider = "None",
		DefaultSetId = "Structure",
		RequiredSlots = table.freeze({ "Idle" }),
		OptionalSlots = table.freeze({ "Attack", "Extract", "Stasis" }),
		CorePoseSlots = table.freeze({
			Idle = "Idle",
		}),
		Channels = table.freeze({
			FullBody = _Channel("FullBody", "FullBodyAction", Enum.AnimationPriority.Action, false, {
				InterruptPriority = 100,
			}),
			LoopingAction = _Channel("LoopingAction", "Action", Enum.AnimationPriority.Action, true, {
				InterruptPriority = 25,
			}),
		}),
		Features = table.freeze({}),
		DisableDefaultAnimate = true,
		RootMotionEnabled = false,
	}),
}

return table.freeze(Profiles)
