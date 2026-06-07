--!strict

export type TAnimationRigAdapterId = "Humanoid" | "AnimationController"
export type TAnimationLocomotionProviderId = "HumanoidState" | "EntityMovement" | "None"
export type TAnimationAimStrategy = "IKControl" | "Motor6D"
export type TAnimationRuntimeState = "PendingModel" | "Loading" | "Ready" | "Suspended" | "Failed" | "Removed"

export type TAnimationProfileComponent = {
	ProfileId: string,
	AnimationSetId: string,
	VariantId: string?,
	FeatureOverrides: TAnimationFeaturePolicy?,
}

export type TAnimationChannelState = {
	ActionId: string,
	Revision: number,
	StartedAt: number?,
	PlaybackSpeed: number?,
}

export type TAnimationActionChannels = {
	[string]: TAnimationChannelState,
}

export type TAnimationSlotId = string
export type TAnimationClipKey = string

export type TAnimationSet = {
	Id: string,
	Extends: { string }?,
	Slots: { [TAnimationSlotId]: TAnimationClipKey },
	Variants: { [string]: { [TAnimationSlotId]: TAnimationClipKey } }?,
}

export type TAnimationChannelPolicy = {
	ChannelId: string,
	SlotId: TAnimationSlotId,
	Priority: Enum.AnimationPriority,
	InterruptPriority: number,
	FadeIn: number,
	FadeOut: number,
	Looped: boolean,
	SuppressLocomotion: boolean?,
	AllowLocalRequests: boolean?,
}

export type TAnimationFeaturePolicy = {
	Lean: any?,
	Aim: any?,
}

export type TAnimationProfile = {
	Id: string,
	RigAdapter: TAnimationRigAdapterId,
	LocomotionProvider: TAnimationLocomotionProviderId,
	DefaultSetId: string,
	RequiredSlots: { TAnimationSlotId },
	OptionalSlots: { TAnimationSlotId }?,
	CorePoseSlots: { [string]: TAnimationSlotId }?,
	Channels: { [string]: TAnimationChannelPolicy },
	Features: TAnimationFeaturePolicy?,
	DisableDefaultAnimate: boolean?,
	RootMotionEnabled: boolean?,
}

export type TCompiledAnimationSet = {
	SetId: string,
	VariantId: string,
	Slots: { [TAnimationSlotId]: TAnimationClipKey },
}

export type TLoadedTrackInfo = {
	Track: AnimationTrack,
	SlotId: TAnimationSlotId,
	ChannelId: string?,
}

export type TAnimationMarkerPayload = {
	Entity: number,
	ActionId: string,
	ChannelId: string,
	MarkerName: string,
	MarkerValue: string?,
}

export type TIKAimRigConfig = {
	Strategy: TAnimationAimStrategy?,
	ChainRootPath: string?,
	EndEffectorPath: string?,
	SmoothTime: number?,
	Weight: number?,
	Priority: number?,
	ReturnToNeutralWhenNoTarget: boolean?,
	MotorPath: string?,
	PartPath: string?,
	YawLimit: number?,
	PitchLimit: number?,
}

export type TSetupAimRequest = {
	Model: Model,
	Strategy: TAnimationAimStrategy?,
	GetTargetWorldPosition: () -> Vector3?,
	RigConfig: TIKAimRigConfig,
	Context: any?,
}

export type TLocalActionRequest = {
	RequestId: string,
	Entity: number,
	ActionId: string,
	ChannelId: string,
	Revision: number,
	StartedAt: number,
	PlaybackSpeed: number,
}

return nil
