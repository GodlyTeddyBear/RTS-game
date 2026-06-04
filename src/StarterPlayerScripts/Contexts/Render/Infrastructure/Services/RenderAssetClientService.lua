--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RenderAssetResolver = require(ReplicatedStorage.Contexts.Render.RenderAssetResolver)

local RenderAssetClientService = {}
RenderAssetClientService.__index = RenderAssetClientService

function RenderAssetClientService.new()
	local assetsRoot = ReplicatedStorage:FindFirstChild("Assets")
	local self = setmetatable({}, RenderAssetClientService)
	self._resolver = RenderAssetResolver.new(if assetsRoot ~= nil and assetsRoot:IsA("Folder") then assetsRoot else nil)
	return self
end

function RenderAssetClientService:GetAssetsRoot(): Folder?
	return self._resolver:GetAssetsRoot()
end

function RenderAssetClientService:ResolveAsset(familyId: any, key: string, options: any)
	return self._resolver:ResolveAsset(familyId, key, options)
end

function RenderAssetClientService:AssetExists(familyId: any, key: string, options: any): boolean
	return self._resolver:AssetExists(familyId, key, options)
end

function RenderAssetClientService:GetStructureModel(structureType: string, options: any): Model?
	return self._resolver:GetStructureModel(structureType, options)
end

function RenderAssetClientService:StructureModelExists(structureType: string, options: any): boolean
	return self._resolver:StructureModelExists(structureType, options)
end

function RenderAssetClientService:GetAnimationClip(actionPath: string, variant: string?, options: any): Animation?
	return self._resolver:GetAnimationClip(actionPath, variant, options)
end

function RenderAssetClientService:AnimationClipExists(actionPath: string, variant: string?, options: any): boolean
	return self._resolver:AnimationClipExists(actionPath, variant, options)
end

function RenderAssetClientService:GetAllAnimationClips(actionPath: string, options: any): { [string]: Animation }
	return self._resolver:GetAllAnimationClips(actionPath, options)
end

function RenderAssetClientService:GetSkillEffect(effectKey: string, options: any): Folder | Model?
	return self._resolver:GetSkillEffect(effectKey, options)
end

function RenderAssetClientService:SkillEffectExists(effectKey: string, options: any): boolean
	return self._resolver:SkillEffectExists(effectKey, options)
end

function RenderAssetClientService:GetStatusEffect(effectKey: string, options: any): Folder | Model?
	return self._resolver:GetStatusEffect(effectKey, options)
end

function RenderAssetClientService:StatusEffectExists(effectKey: string, options: any): boolean
	return self._resolver:StatusEffectExists(effectKey, options)
end

function RenderAssetClientService:GetCombatSound(soundPath: string, options: any): Sound?
	return self._resolver:GetCombatSound(soundPath, options)
end

function RenderAssetClientService:CombatSoundExists(soundPath: string, options: any): boolean
	return self._resolver:CombatSoundExists(soundPath, options)
end

function RenderAssetClientService:GetUISound(soundPath: string, options: any): Sound?
	return self._resolver:GetUISound(soundPath, options)
end

function RenderAssetClientService:UISoundExists(soundPath: string, options: any): boolean
	return self._resolver:UISoundExists(soundPath, options)
end

function RenderAssetClientService:GetToolModel(assetId: string, options: any): Model?
	return self._resolver:GetToolModel(assetId, options)
end

function RenderAssetClientService:ToolModelExists(assetId: string, options: any): boolean
	return self._resolver:ToolModelExists(assetId, options)
end

function RenderAssetClientService:GetArmorModel(assetId: string, options: any): Model?
	return self._resolver:GetArmorModel(assetId, options)
end

function RenderAssetClientService:ArmorModelExists(assetId: string, options: any): boolean
	return self._resolver:ArmorModelExists(assetId, options)
end

function RenderAssetClientService:GetAccessoryModel(assetId: string, options: any): Model?
	return self._resolver:GetAccessoryModel(assetId, options)
end

function RenderAssetClientService:AccessoryModelExists(assetId: string, options: any): boolean
	return self._resolver:AccessoryModelExists(assetId, options)
end

return RenderAssetClientService
