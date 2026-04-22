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

export type TRig = {
	Humanoid: Humanoid,
	Animator: Animator,
}

export type TLoadedClips = {
	CoreAnimations: { [string]: { TAnimInfo } },
	Actions: { TActionEntry },
	Emotes: { TActionEntry },
}

export type TAnimationPreset = {
	Tag: string,
	Debug: boolean?,
	AnimationsFolder: Folder?,
	VariantAttribute: string?,
	DefaultVariant: string?,
	ReloadOnVariantChanged: boolean?,
	CorePoseFolders: { TPoseFolder },
	AllPoses: { string },
	PoseFallbacks: { [string]: string },
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
