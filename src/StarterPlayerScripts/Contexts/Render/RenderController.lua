--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)

local RenderAssetClientService = require(script.Parent.Infrastructure.Services.RenderAssetClientService)
local RenderRegistryClientService = require(script.Parent.Infrastructure.Services.RenderRegistryClientService)
local RenderProfileService = require(script.Parent.Infrastructure.Services.RenderProfileService)
local RenderVisualReplacementService = require(script.Parent.Infrastructure.Services.RenderVisualReplacementService)

local RenderController = Knit.CreateController({
	Name = "RenderController",
})

function RenderController:KnitInit()
	self._renderAssetClientService = RenderAssetClientService.new()
	self._renderRegistryClientService = RenderRegistryClientService.new()
	self._renderProfileService = RenderProfileService.new(self._renderRegistryClientService)
	self._renderVisualReplacementService = RenderVisualReplacementService.new(self._renderRegistryClientService)
end

function RenderController:KnitStart()
	self._renderRegistryClientService:Start()
	self._renderProfileService:Start()
	self._renderVisualReplacementService:Start()
end

function RenderController:Destroy()
	if self._renderProfileService == nil then
		self._renderAssetClientService = nil
		if self._renderVisualReplacementService ~= nil then
			self._renderVisualReplacementService:Destroy()
			self._renderVisualReplacementService = nil
		end
		if self._renderRegistryClientService ~= nil then
			self._renderRegistryClientService:Destroy()
			self._renderRegistryClientService = nil
		end
		return
	end

	self._renderProfileService:Destroy()
	self._renderProfileService = nil
	self._renderAssetClientService = nil

	if self._renderVisualReplacementService ~= nil then
		self._renderVisualReplacementService:Destroy()
		self._renderVisualReplacementService = nil
	end

	if self._renderRegistryClientService ~= nil then
		self._renderRegistryClientService:Destroy()
		self._renderRegistryClientService = nil
	end
end

function RenderController:GetAssetsRoot(): Folder?
	return self._renderAssetClientService:GetAssetsRoot()
end

function RenderController:ResolveAsset(familyId: any, key: string, options: any)
	return self._renderAssetClientService:ResolveAsset(familyId, key, options)
end

function RenderController:AssetExists(familyId: any, key: string, options: any): boolean
	return self._renderAssetClientService:AssetExists(familyId, key, options)
end

function RenderController:GetStructureModel(structureType: string, options: any): Model?
	return self._renderAssetClientService:GetStructureModel(structureType, options)
end

function RenderController:StructureModelExists(structureType: string, options: any): boolean
	return self._renderAssetClientService:StructureModelExists(structureType, options)
end

function RenderController:GetAnimationClip(actionPath: string, variant: string?, options: any): Animation?
	return self._renderAssetClientService:GetAnimationClip(actionPath, variant, options)
end

function RenderController:AnimationClipExists(actionPath: string, variant: string?, options: any): boolean
	return self._renderAssetClientService:AnimationClipExists(actionPath, variant, options)
end

function RenderController:GetAllAnimationClips(actionPath: string, options: any): { [string]: Animation }
	return self._renderAssetClientService:GetAllAnimationClips(actionPath, options)
end

function RenderController:GetSkillEffect(effectKey: string, options: any): Folder | Model?
	return self._renderAssetClientService:GetSkillEffect(effectKey, options)
end

function RenderController:SkillEffectExists(effectKey: string, options: any): boolean
	return self._renderAssetClientService:SkillEffectExists(effectKey, options)
end

function RenderController:GetStatusEffect(effectKey: string, options: any): Folder | Model?
	return self._renderAssetClientService:GetStatusEffect(effectKey, options)
end

function RenderController:StatusEffectExists(effectKey: string, options: any): boolean
	return self._renderAssetClientService:StatusEffectExists(effectKey, options)
end

function RenderController:GetCombatSound(soundPath: string, options: any): Sound?
	return self._renderAssetClientService:GetCombatSound(soundPath, options)
end

function RenderController:CombatSoundExists(soundPath: string, options: any): boolean
	return self._renderAssetClientService:CombatSoundExists(soundPath, options)
end

function RenderController:GetUISound(soundPath: string, options: any): Sound?
	return self._renderAssetClientService:GetUISound(soundPath, options)
end

function RenderController:UISoundExists(soundPath: string, options: any): boolean
	return self._renderAssetClientService:UISoundExists(soundPath, options)
end

function RenderController:GetToolModel(assetId: string, options: any): Model?
	return self._renderAssetClientService:GetToolModel(assetId, options)
end

function RenderController:ToolModelExists(assetId: string, options: any): boolean
	return self._renderAssetClientService:ToolModelExists(assetId, options)
end

function RenderController:GetArmorModel(assetId: string, options: any): Model?
	return self._renderAssetClientService:GetArmorModel(assetId, options)
end

function RenderController:ArmorModelExists(assetId: string, options: any): boolean
	return self._renderAssetClientService:ArmorModelExists(assetId, options)
end

function RenderController:GetAccessoryModel(assetId: string, options: any): Model?
	return self._renderAssetClientService:GetAccessoryModel(assetId, options)
end

function RenderController:AccessoryModelExists(assetId: string, options: any): boolean
	return self._renderAssetClientService:AccessoryModelExists(assetId, options)
end

return RenderController
