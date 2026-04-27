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

export type TAnimationPresetOptions = {
	AnimationsFolder: Folder?,
}

export type TAnimationPreset = {
	Id: TPresetId,
	Tag: string,
	Debug: boolean?,
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
