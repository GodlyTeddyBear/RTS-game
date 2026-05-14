--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EnumList = require(ReplicatedStorage.Utilities.EnumList)
local StashTypes = require(ReplicatedStorage.Utilities.StashPlus.src.Types)

export type TEffectCategory = EnumList.EnumItem | "Skill" | "StatusEffect"

export type TVFXRegistry = {
	SkillEffectExists: (self: TVFXRegistry, effectKey: string) -> boolean,
	GetSkillEffect: (self: TVFXRegistry, effectKey: string) -> Folder | Model,
	StatusEffectExists: (self: TVFXRegistry, effectKey: string) -> boolean,
	GetStatusEffect: (self: TVFXRegistry, effectKey: string) -> Folder | Model,
}

export type TVFXRequest = {
	EffectKey: string,
	Category: TEffectCategory?,
	Parent: Instance?,
	Position: Vector3?,
	CFrame: CFrame?,
	Target: Instance?,
	Offset: CFrame?,
	Lifetime: number?,
	EmitCount: number?,
	AutoCleanup: boolean?,
	Metadata: { [string]: any }?,
}

export type TRuntimeFolderOptions = {
	ReplaceInvalid: boolean?,
}

export type TResolvedAttachTarget = {
	TargetPart: BasePart?,
	CFrame: CFrame,
}

export type TPreparedVFXRequest = {
	EffectKey: string,
	Category: EnumList.EnumItem,
	Parent: Instance,
	CFrame: CFrame,
	Target: Instance?,
	TargetPart: BasePart?,
	Offset: CFrame?,
	Lifetime: number?,
	EmitCount: number?,
	AutoCleanup: boolean,
	Metadata: { [string]: any }?,
}

export type TVFXHandle = {
	Container: Folder | Model,
	Anchor: Model,
	Root: BasePart,
	Stash: StashTypes.TStash,
	EffectKey: string,
	Category: EnumList.EnumItem,
	Lifetime: number,
	AutoCleanup: boolean,
	CleanupScheduled: boolean,
	Metadata: { [string]: any }?,
	Cleanup: (self: TVFXHandle) -> StashTypes.TCleanupReport,
	Destroy: (self: TVFXHandle) -> StashTypes.TCleanupReport,
	IsDestroyed: (self: TVFXHandle) -> boolean,
}

return table.freeze({})
