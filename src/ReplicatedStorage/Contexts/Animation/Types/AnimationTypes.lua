--!strict

export type TPoseFolder = {
	Folder: string,
	Pose: string,
}

export type TAnimInfo = {
	anim: AnimationTrack,
	weight: number,
}

export type TActionEntry = {
	Action: string,
	AnimInfos: { TAnimInfo },
}

export type TLoadedClips = {
	CoreAnimations: { [string]: { TAnimInfo } },
	Actions: { TActionEntry },
	Emotes: { TActionEntry },
}

export type TPoseFilterMode = "Whitelist" | "Blacklist"
export type TPresetId = "Player" | "Worker" | "CombatNPC" | "EnemyLocomotion" | "Structure"
export type TAimStrategy = "IKControl"
export type TReplicatedStateMode = "ActionOnly" | "FullState"

export type TAnimationActionSnapshot = {
	State: string,
	Looping: boolean,
	Revision: number,
}

export type TAnimationStateSource = {
	GetState: (self: TAnimationStateSource) -> string?,
	GetLooping: (self: TAnimationStateSource) -> boolean?,
	GetRevision: ((self: TAnimationStateSource) -> number?)?,
	GetActionAnimation: ((self: TAnimationStateSource) -> TAnimationActionSnapshot?)?,
	ObserveStateChanged: (self: TAnimationStateSource, callback: () -> ()) -> (() -> ()),
	ObserveLoopingChanged: (self: TAnimationStateSource, callback: () -> ()) -> (() -> ()),
	ObserveRevisionChanged: ((self: TAnimationStateSource, callback: () -> ()) -> (() -> ()))?,
	ObserveActionAnimationChanged: ((self: TAnimationStateSource, callback: () -> ()) -> (() -> ()))?,
}

export type TAnimationPresetOptions = {
	AnimationsFolder: Folder?,
	StateSource: TAnimationStateSource?,
}

export type TIKAimRigConfig = {
	ChainRootPath: string?,
	EndEffectorPath: string?,
	SmoothTime: number?,
	Weight: number?,
	Priority: number?,
	ReturnToNeutralWhenNoTarget: boolean?,
}

export type TSetupAimRequest = {
	Model: Model,
	Strategy: TAimStrategy,
	GetTargetWorldPosition: () -> Vector3?,
	RigConfig: TIKAimRigConfig,
	Context: any?,
}

export type TAnimationPreset = {
	Id: TPresetId,
	Tag: string,
	Debug: boolean?,
	ReplicatedStateMode: TReplicatedStateMode?,
	AnimationsFolder: Folder?,
	VariantAttribute: string?,
	DefaultVariant: string?,
	ReloadOnVariantChanged: boolean?,
	CorePoseFolders: { TPoseFolder },
	AllPoses: { string },
	PoseFallbacks: { [string]: string },
	PoseFilterMode: TPoseFilterMode?,
	PoseFilter: { [string]: boolean }?,
	EnableEmotes: boolean?,
	EmoteFolders: { [string]: boolean }?,
	WarnOnMissingPose: boolean?,
	WarnOnMissingAnimation: boolean?,
	UseDirectAnimationsFolder: boolean?,
	UseStateDrivenCorePoses: boolean?,
	ActionNameTransform: ((string) -> string)?,
	ActionStateFallback: ((string, { [string]: boolean }) -> string?)?,
}

return nil
