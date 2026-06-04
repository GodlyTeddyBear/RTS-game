--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Knit = require(ReplicatedStorage.Packages.Knit)
local RenderAssetResolver = require(script.Parent.RenderAssetResolver)

local RenderAssetAccess = {}

local fallbackResolver = nil
local cachedServerRenderContext = nil
local cachedClientRenderController = nil

local function _GetFallbackResolver()
	if fallbackResolver == nil then
		local assetsRoot = ReplicatedStorage:FindFirstChild("Assets")
		fallbackResolver = RenderAssetResolver.new(if assetsRoot ~= nil and assetsRoot:IsA("Folder") then assetsRoot else nil)
	end
	return fallbackResolver
end

local function _GetServerRenderContext()
	if cachedServerRenderContext ~= nil then
		return cachedServerRenderContext
	end

	local ok, renderContext = pcall(function()
		return Knit.GetService("RenderContext")
	end)
	if ok and renderContext ~= nil then
		cachedServerRenderContext = renderContext
	end

	return cachedServerRenderContext
end

local function _GetClientRenderController()
	if cachedClientRenderController ~= nil then
		return cachedClientRenderController
	end

	local ok, renderController = pcall(function()
		return Knit.GetController("RenderController")
	end)
	if ok and renderController ~= nil then
		cachedClientRenderController = renderController
	end

	return cachedClientRenderController
end

local function _Invoke(methodName: string, ...: any): any
	if RunService:IsServer() then
		local renderContext = _GetServerRenderContext()
		if renderContext ~= nil and type(renderContext[methodName]) == "function" then
			local result = renderContext[methodName](renderContext, ...)
			if type(result) == "table" and result.success ~= nil then
				if result.success then
					return result.value
				end
				return nil
			end
			return result
		end
		return _GetFallbackResolver()[methodName](_GetFallbackResolver(), ...)
	end

	local renderController = _GetClientRenderController()
	if renderController ~= nil and type(renderController[methodName]) == "function" then
		return renderController[methodName](renderController, ...)
	end
	return _GetFallbackResolver()[methodName](_GetFallbackResolver(), ...)
end

function RenderAssetAccess.GetAssetsRoot(): Folder?
	return _Invoke("GetAssetsRoot")
end

function RenderAssetAccess.ResolveAsset(familyId: any, key: string, options: any)
	return _Invoke("ResolveAsset", familyId, key, options)
end

function RenderAssetAccess.AssetExists(familyId: any, key: string, options: any): boolean
	return _Invoke("AssetExists", familyId, key, options) == true
end

function RenderAssetAccess.GetStructureModel(structureType: string, options: any): Model?
	return _Invoke("GetStructureModel", structureType, options)
end

function RenderAssetAccess.StructureModelExists(structureType: string, options: any): boolean
	return _Invoke("StructureModelExists", structureType, options) == true
end

function RenderAssetAccess.GetAnimationClip(actionPath: string, variant: string?, options: any): Animation?
	return _Invoke("GetAnimationClip", actionPath, variant, options)
end

function RenderAssetAccess.AnimationClipExists(actionPath: string, variant: string?, options: any): boolean
	return _Invoke("AnimationClipExists", actionPath, variant, options) == true
end

function RenderAssetAccess.GetAllAnimationClips(actionPath: string, options: any): { [string]: Animation }
	return _Invoke("GetAllAnimationClips", actionPath, options) or {}
end

function RenderAssetAccess.GetSkillEffect(effectKey: string, options: any): Folder | Model?
	return _Invoke("GetSkillEffect", effectKey, options)
end

function RenderAssetAccess.SkillEffectExists(effectKey: string, options: any): boolean
	return _Invoke("SkillEffectExists", effectKey, options) == true
end

function RenderAssetAccess.GetStatusEffect(effectKey: string, options: any): Folder | Model?
	return _Invoke("GetStatusEffect", effectKey, options)
end

function RenderAssetAccess.StatusEffectExists(effectKey: string, options: any): boolean
	return _Invoke("StatusEffectExists", effectKey, options) == true
end

function RenderAssetAccess.GetCombatSound(soundPath: string, options: any): Sound?
	return _Invoke("GetCombatSound", soundPath, options)
end

function RenderAssetAccess.CombatSoundExists(soundPath: string, options: any): boolean
	return _Invoke("CombatSoundExists", soundPath, options) == true
end

function RenderAssetAccess.GetUISound(soundPath: string, options: any): Sound?
	return _Invoke("GetUISound", soundPath, options)
end

function RenderAssetAccess.UISoundExists(soundPath: string, options: any): boolean
	return _Invoke("UISoundExists", soundPath, options) == true
end

function RenderAssetAccess.GetToolModel(assetId: string, options: any): Model?
	return _Invoke("GetToolModel", assetId, options)
end

function RenderAssetAccess.ToolModelExists(assetId: string, options: any): boolean
	return _Invoke("ToolModelExists", assetId, options) == true
end

function RenderAssetAccess.GetArmorModel(assetId: string, options: any): Model?
	return _Invoke("GetArmorModel", assetId, options)
end

function RenderAssetAccess.ArmorModelExists(assetId: string, options: any): boolean
	return _Invoke("ArmorModelExists", assetId, options) == true
end

function RenderAssetAccess.GetAccessoryModel(assetId: string, options: any): Model?
	return _Invoke("GetAccessoryModel", assetId, options)
end

function RenderAssetAccess.AccessoryModelExists(assetId: string, options: any): boolean
	return _Invoke("AccessoryModelExists", assetId, options) == true
end

return table.freeze(RenderAssetAccess)
