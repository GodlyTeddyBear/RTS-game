--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EnumList = require(ReplicatedStorage.Utilities.EnumList)

local Enums = {
	EffectCategory = EnumList.new("VFXPlusEffectCategory", {
		"Skill",
		"StatusEffect",
	}),
	ErrorKey = EnumList.new("VFXPlusErrorKey", {
		"InvalidRegistry",
		"InvalidRequest",
		"InvalidEffectKey",
		"InvalidCategory",
		"InvalidParent",
		"InvalidSpawnRequest",
		"InvalidAttachTarget",
		"InvalidLifetime",
		"InvalidEmitCount",
		"InvalidAutoCleanup",
		"InvalidRuntimeParent",
		"InvalidRuntimeFolderName",
		"RuntimeFolderConflict",
		"InvalidEffectsFolder",
		"RegistryCreateFailed",
		"EffectNotFound",
		"EffectCloneFailed",
	}),
}

Enums.ErrorMessage = table.freeze({
	[Enums.ErrorKey.InvalidRegistry] = "VFXPlus requires an EffectRegistry-like object",
	[Enums.ErrorKey.InvalidRequest] = "VFXPlus request must be a table",
	[Enums.ErrorKey.InvalidEffectKey] = "VFXPlus EffectKey must be a non-empty string",
	[Enums.ErrorKey.InvalidCategory] = "VFXPlus Category must be Skill or StatusEffect",
	[Enums.ErrorKey.InvalidParent] = "VFXPlus Parent must be a live Instance",
	[Enums.ErrorKey.InvalidSpawnRequest] = "VFXPlus spawn requests require Position or CFrame",
	[Enums.ErrorKey.InvalidAttachTarget] = "VFXPlus attach requests require a resolvable BasePart, Model, or Attachment target",
	[Enums.ErrorKey.InvalidLifetime] = "VFXPlus Lifetime must be a positive number when provided",
	[Enums.ErrorKey.InvalidEmitCount] = "VFXPlus EmitCount must be a positive number when provided",
	[Enums.ErrorKey.InvalidAutoCleanup] = "VFXPlus AutoCleanup must be a boolean when provided",
	[Enums.ErrorKey.InvalidRuntimeParent] = "VFXPlus runtime parent must be a live Instance when provided",
	[Enums.ErrorKey.InvalidRuntimeFolderName] = "VFXPlus runtime folder name must be a non-empty string when provided",
	[Enums.ErrorKey.RuntimeFolderConflict] = "VFXPlus runtime folder name is already used by a non-Folder instance",
	[Enums.ErrorKey.InvalidEffectsFolder] = "VFXPlus CreateEffectRegistry requires a live Folder instance",
	[Enums.ErrorKey.RegistryCreateFailed] = "VFXPlus failed to create a valid effect registry",
	[Enums.ErrorKey.EffectNotFound] = "VFXPlus effect was not found in the requested category",
	[Enums.ErrorKey.EffectCloneFailed] = "VFXPlus failed to clone the requested effect",
})

return table.freeze(Enums)
