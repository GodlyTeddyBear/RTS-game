--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RenderAssetResolver = require(ReplicatedStorage.Contexts.Render.RenderAssetResolver)

local RenderAssetService = {}
RenderAssetService.__index = RenderAssetService

function RenderAssetService.new()
	local assetsRoot = ReplicatedStorage:FindFirstChild("Assets")
	local self = setmetatable({}, RenderAssetService)
	self._resolver = RenderAssetResolver.new(if assetsRoot ~= nil and assetsRoot:IsA("Folder") then assetsRoot else nil)
	return self
end

function RenderAssetService:GetAssetsRoot(): Folder?
	return self._resolver:GetAssetsRoot()
end

function RenderAssetService:ResolveAsset(familyId: any, key: string, options: any)
	return self._resolver:ResolveAsset(familyId, key, options)
end

function RenderAssetService:AssetExists(familyId: any, key: string, options: any): boolean
	return self._resolver:AssetExists(familyId, key, options)
end

function RenderAssetService:GetStructureModel(structureType: string, options: any): Model?
	return self._resolver:GetStructureModel(structureType, options)
end

function RenderAssetService:StructureModelExists(structureType: string, options: any): boolean
	return self._resolver:StructureModelExists(structureType, options)
end

function RenderAssetService:GetAnimationClip(actionPath: string, variant: string?, options: any): Animation?
	return self._resolver:GetAnimationClip(actionPath, variant, options)
end

function RenderAssetService:AnimationClipExists(actionPath: string, variant: string?, options: any): boolean
	return self._resolver:AnimationClipExists(actionPath, variant, options)
end

function RenderAssetService:GetAllAnimationClips(actionPath: string, options: any): { [string]: Animation }
	return self._resolver:GetAllAnimationClips(actionPath, options)
end

function RenderAssetService:GetSkillEffect(effectKey: string, options: any): Folder | Model?
	return self._resolver:GetSkillEffect(effectKey, options)
end

function RenderAssetService:SkillEffectExists(effectKey: string, options: any): boolean
	return self._resolver:SkillEffectExists(effectKey, options)
end

function RenderAssetService:GetStatusEffect(effectKey: string, options: any): Folder | Model?
	return self._resolver:GetStatusEffect(effectKey, options)
end

function RenderAssetService:StatusEffectExists(effectKey: string, options: any): boolean
	return self._resolver:StatusEffectExists(effectKey, options)
end

function RenderAssetService:GetCombatSound(soundPath: string, options: any): Sound?
	return self._resolver:GetCombatSound(soundPath, options)
end

function RenderAssetService:CombatSoundExists(soundPath: string, options: any): boolean
	return self._resolver:CombatSoundExists(soundPath, options)
end

function RenderAssetService:GetUISound(soundPath: string, options: any): Sound?
	return self._resolver:GetUISound(soundPath, options)
end

function RenderAssetService:UISoundExists(soundPath: string, options: any): boolean
	return self._resolver:UISoundExists(soundPath, options)
end

function RenderAssetService:GetToolModel(assetId: string, options: any): Model?
	return self._resolver:GetToolModel(assetId, options)
end

function RenderAssetService:ToolModelExists(assetId: string, options: any): boolean
	return self._resolver:ToolModelExists(assetId, options)
end

function RenderAssetService:GetArmorModel(assetId: string, options: any): Model?
	return self._resolver:GetArmorModel(assetId, options)
end

function RenderAssetService:ArmorModelExists(assetId: string, options: any): boolean
	return self._resolver:ArmorModelExists(assetId, options)
end

function RenderAssetService:GetAccessoryModel(assetId: string, options: any): Model?
	return self._resolver:GetAccessoryModel(assetId, options)
end

function RenderAssetService:AccessoryModelExists(assetId: string, options: any): boolean
	return self._resolver:AccessoryModelExists(assetId, options)
end

return RenderAssetService
