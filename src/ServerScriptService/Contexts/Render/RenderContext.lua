--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local BaseContext = require(ServerStorage.Utilities.ContextUtilities.BaseContext)
local Result = require(ReplicatedStorage.Utilities.Result)

local RenderAccessoryService = require(script.Parent.Infrastructure.Services.RenderAccessoryService)
local RenderAssetService = require(script.Parent.Infrastructure.Services.RenderAssetService)
local RenderExportService = require(script.Parent.Infrastructure.Services.RenderExportService)
local RenderRegistryService = require(script.Parent.Infrastructure.Services.RenderRegistryService)
local RenderRuntimeService = require(script.Parent.Infrastructure.Services.RenderRuntimeService)

local Ok = Result.Ok

local InfrastructureModules: { BaseContext.TModuleSpec } = {
	{
		Name = "ClientSignals",
		Factory = function(service: any, _baseContext: any)
			return service.Client
		end,
	},
	{
		Name = "RenderAccessoryService",
		Module = RenderAccessoryService,
		CacheAs = "_renderAccessoryService",
	},
	{
		Name = "RenderAssetService",
		Module = RenderAssetService,
		CacheAs = "_renderAssetService",
	},
	{
		Name = "RenderExportService",
		Module = RenderExportService,
		CacheAs = "_renderExportService",
	},
	{
		Name = "RenderRegistryService",
		Module = RenderRegistryService,
		CacheAs = "_renderRegistryService",
	},
	{
		Name = "RenderRuntimeService",
		Module = RenderRuntimeService,
		CacheAs = "_renderRuntimeService",
	},
}

local RenderModules: BaseContext.TModuleLayers = {
	Infrastructure = InfrastructureModules,
}

local RenderContext = Knit.CreateService({
	Name = "RenderContext",
	Client = {
		RenderRegistryBootstrapChunk = Knit.CreateSignal(),
		RenderRegistryDelta = Knit.CreateSignal(),
		RenderAccessoryBootstrapChunk = Knit.CreateSignal(),
		RenderAccessoryDelta = Knit.CreateSignal(),
	},
	Modules = RenderModules,
	Teardown = {
		Fields = {
			{ Field = "_renderRuntimeService", Method = "Destroy" },
			{ Field = "_renderRegistryService", Method = "Destroy" },
			{ Field = "_renderAccessoryService", Method = "Destroy" },
			{ Field = "_renderAssetService", Method = "Destroy" },
			{ Field = "_renderExportService", Method = "Destroy" },
		},
	},
})

local RenderBaseContext = BaseContext.new(RenderContext)

function RenderContext:KnitInit()
	RenderBaseContext:KnitInit()
end

function RenderContext:KnitStart()
	RenderBaseContext:KnitStart()
end

function RenderContext:GetTrackedIndexById(id: string): Result.Result<number?>
	return Ok(self._renderRegistryService:GetIndexById(id))
end

function RenderContext:GetTrackedInstanceById(id: string): Result.Result<Instance?>
	return Ok(self._renderRegistryService:GetInstanceById(id))
end

function RenderContext:GetTrackedPropertyValueById(propertyKey: string, id: string): Result.Result<any>
	return Ok(self._renderRegistryService:GetPropertyValueById(propertyKey, id))
end

function RenderContext:GetTrackedCastShadowById(id: string): Result.Result<boolean?>
	return Ok(self._renderRegistryService:GetPropertyValueById("CastShadow", id))
end

function RenderContext:GetRegistrySoA(): Result.Result<any>
	return Ok(self._renderRegistryService:GetRegistrySoA())
end

function RenderContext:GetAssetsRoot(): Result.Result<Folder?>
	return Ok(self._renderAssetService:GetAssetsRoot())
end

function RenderContext:ResolveAsset(familyId: any, key: string, options: any): Result.Result<any>
	return Ok(self._renderAssetService:ResolveAsset(familyId, key, options))
end

function RenderContext:AssetExists(familyId: any, key: string, options: any): Result.Result<boolean>
	return Ok(self._renderAssetService:AssetExists(familyId, key, options))
end

function RenderContext:GetStructureModel(structureType: string, options: any): Result.Result<Model?>
	return Ok(self._renderAssetService:GetStructureModel(structureType, options))
end

function RenderContext:StructureModelExists(structureType: string, options: any): Result.Result<boolean>
	return Ok(self._renderAssetService:StructureModelExists(structureType, options))
end

function RenderContext:GetAnimationClip(
	actionPath: string,
	variant: string?,
	options: any
): Result.Result<Animation?>
	return Ok(self._renderAssetService:GetAnimationClip(actionPath, variant, options))
end

function RenderContext:AnimationClipExists(
	actionPath: string,
	variant: string?,
	options: any
): Result.Result<boolean>
	return Ok(self._renderAssetService:AnimationClipExists(actionPath, variant, options))
end

function RenderContext:GetAllAnimationClips(actionPath: string, options: any): Result.Result<{ [string]: Animation }>
	return Ok(self._renderAssetService:GetAllAnimationClips(actionPath, options))
end

function RenderContext:GetSkillEffect(effectKey: string, options: any): Result.Result<Folder | Model?>
	return Ok(self._renderAssetService:GetSkillEffect(effectKey, options))
end

function RenderContext:SkillEffectExists(effectKey: string, options: any): Result.Result<boolean>
	return Ok(self._renderAssetService:SkillEffectExists(effectKey, options))
end

function RenderContext:GetStatusEffect(effectKey: string, options: any): Result.Result<Folder | Model?>
	return Ok(self._renderAssetService:GetStatusEffect(effectKey, options))
end

function RenderContext:StatusEffectExists(effectKey: string, options: any): Result.Result<boolean>
	return Ok(self._renderAssetService:StatusEffectExists(effectKey, options))
end

function RenderContext:GetCombatSound(soundPath: string, options: any): Result.Result<Sound?>
	return Ok(self._renderAssetService:GetCombatSound(soundPath, options))
end

function RenderContext:CombatSoundExists(soundPath: string, options: any): Result.Result<boolean>
	return Ok(self._renderAssetService:CombatSoundExists(soundPath, options))
end

function RenderContext:GetUISound(soundPath: string, options: any): Result.Result<Sound?>
	return Ok(self._renderAssetService:GetUISound(soundPath, options))
end

function RenderContext:UISoundExists(soundPath: string, options: any): Result.Result<boolean>
	return Ok(self._renderAssetService:UISoundExists(soundPath, options))
end

function RenderContext:GetToolModel(assetId: string, options: any): Result.Result<Model?>
	return Ok(self._renderAssetService:GetToolModel(assetId, options))
end

function RenderContext:ToolModelExists(assetId: string, options: any): Result.Result<boolean>
	return Ok(self._renderAssetService:ToolModelExists(assetId, options))
end

function RenderContext:GetArmorModel(assetId: string, options: any): Result.Result<Model?>
	return Ok(self._renderAssetService:GetArmorModel(assetId, options))
end

function RenderContext:ArmorModelExists(assetId: string, options: any): Result.Result<boolean>
	return Ok(self._renderAssetService:ArmorModelExists(assetId, options))
end

function RenderContext:GetAccessoryModel(assetId: string, options: any): Result.Result<Model?>
	return Ok(self._renderAssetService:GetAccessoryModel(assetId, options))
end

function RenderContext:AccessoryModelExists(assetId: string, options: any): Result.Result<boolean>
	return Ok(self._renderAssetService:AccessoryModelExists(assetId, options))
end

function RenderContext.Client:RequestRenderRegistryBootstrap(player: Player): boolean
	return self.Server._renderRegistryService:HydratePlayer(player)
end

function RenderContext.Client:RequestRenderAccessoryBootstrap(player: Player): boolean
	return self.Server._renderAccessoryService:HydratePlayer(player)
end

return RenderContext
