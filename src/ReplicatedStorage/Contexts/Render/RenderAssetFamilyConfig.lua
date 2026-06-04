--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local StructureConfig = require(ReplicatedStorage.Contexts.Structure.Config.StructureConfig)

export type TRenderAssetFamilyId =
	"StructureModel"
	| "AnimationClip"
	| "SkillEffect"
	| "StatusEffect"
	| "CombatSound"
	| "UISound"
	| "ToolModel"
	| "ArmorModel"
	| "AccessoryModel"

export type TRenderAssetResolveOptions = {
	Root: Folder?,
	Variant: string?,
}

export type TRenderAssetResolveResult = {
	FamilyId: TRenderAssetFamilyId,
	Key: string,
	NormalizedKey: string,
	SourceInstance: Instance,
	UsedFallback: boolean,
	Value: any,
}

export type TRenderAssetFamilyConfig = {
	FamilyId: TRenderAssetFamilyId,
	RootPath: { string },
	NormalizeKey: ((key: string, options: TRenderAssetResolveOptions?) -> string)?,
	BuildCandidatePaths: (normalizedKey: string, options: TRenderAssetResolveOptions?) -> { { string } },
	Materialize: (instance: Instance, options: TRenderAssetResolveOptions?) -> any?,
}

local RenderAssetFamilyConfig = {}

local function _SplitPath(path: string): { string }
	local segments = {}
	for _, segment in ipairs(string.split(path, "/")) do
		if segment ~= "" then
			table.insert(segments, segment)
		end
	end
	return segments
end

local function _NormalizeStructureKey(key: string, _options: TRenderAssetResolveOptions?): string
	return StructureConfig.TYPE_ALIASES[key] or key
end

local function _BuildDefaultFallbackPaths(normalizedKey: string, _options: TRenderAssetResolveOptions?): { { string } }
	return {
		{ normalizedKey },
		{ "Default" },
	}
end

local function _BuildAnimationCandidatePaths(
	normalizedKey: string,
	options: TRenderAssetResolveOptions?
): { { string } }
	local resolvedVariant = if options ~= nil and type(options.Variant) == "string" and options.Variant ~= ""
		then options.Variant
		else "Default"
	local actionSegments = _SplitPath(normalizedKey)
	local candidatePaths = {}

	table.insert(candidatePaths, table.clone(actionSegments))
	table.insert(candidatePaths[#candidatePaths], resolvedVariant)

	if resolvedVariant ~= "Default" then
		table.insert(candidatePaths, table.clone(actionSegments))
		table.insert(candidatePaths[#candidatePaths], "Default")
	end

	return candidatePaths
end

local function _BuildDirectPaths(normalizedKey: string, _options: TRenderAssetResolveOptions?): { { string } }
	return {
		_SplitPath(normalizedKey),
	}
end

local function _ExtractModel(instance: Instance): Model?
	if instance:IsA("Model") then
		return instance
	end
	if instance:IsA("Folder") then
		return instance:FindFirstChildWhichIsA("Model")
	end
	return nil
end

local function _CloneModel(instance: Instance, _options: TRenderAssetResolveOptions?): Model?
	local model = _ExtractModel(instance)
	if model == nil then
		return nil
	end
	return model:Clone()
end

local function _ReturnAnimation(instance: Instance, _options: TRenderAssetResolveOptions?): Animation?
	if instance:IsA("Animation") then
		return instance
	end
	if instance:IsA("Folder") then
		return instance:FindFirstChildWhichIsA("Animation")
	end
	return nil
end

local function _CloneEffect(instance: Instance, _options: TRenderAssetResolveOptions?): Folder | Model?
	if instance:IsA("Folder") or instance:IsA("Model") then
		return instance:Clone()
	end
	return nil
end

local function _CloneSound(instance: Instance, _options: TRenderAssetResolveOptions?): Sound?
	if instance:IsA("Sound") then
		return instance:Clone()
	end
	if instance:IsA("Folder") then
		local sound = instance:FindFirstChildWhichIsA("Sound")
		if sound ~= nil then
			return sound:Clone()
		end
	end
	return nil
end

local FAMILY_CONFIGS: { [TRenderAssetFamilyId]: TRenderAssetFamilyConfig } = {
	StructureModel = {
		FamilyId = "StructureModel",
		RootPath = { "Structures" },
		NormalizeKey = _NormalizeStructureKey,
		BuildCandidatePaths = _BuildDefaultFallbackPaths,
		Materialize = _CloneModel,
	},
	AnimationClip = {
		FamilyId = "AnimationClip",
		RootPath = { "Animations" },
		BuildCandidatePaths = _BuildAnimationCandidatePaths,
		Materialize = _ReturnAnimation,
	},
	SkillEffect = {
		FamilyId = "SkillEffect",
		RootPath = { "Effects", "Skills" },
		BuildCandidatePaths = _BuildDirectPaths,
		Materialize = _CloneEffect,
	},
	StatusEffect = {
		FamilyId = "StatusEffect",
		RootPath = { "Effects", "StatusEffects" },
		BuildCandidatePaths = _BuildDirectPaths,
		Materialize = _CloneEffect,
	},
	CombatSound = {
		FamilyId = "CombatSound",
		RootPath = { "Sounds", "Combat" },
		BuildCandidatePaths = _BuildDirectPaths,
		Materialize = _CloneSound,
	},
	UISound = {
		FamilyId = "UISound",
		RootPath = { "Sounds", "UI" },
		BuildCandidatePaths = _BuildDirectPaths,
		Materialize = _CloneSound,
	},
	ToolModel = {
		FamilyId = "ToolModel",
		RootPath = { "Items", "Tools" },
		BuildCandidatePaths = _BuildDefaultFallbackPaths,
		Materialize = _CloneModel,
	},
	ArmorModel = {
		FamilyId = "ArmorModel",
		RootPath = { "Items", "Armor" },
		BuildCandidatePaths = _BuildDefaultFallbackPaths,
		Materialize = _CloneModel,
	},
	AccessoryModel = {
		FamilyId = "AccessoryModel",
		RootPath = { "Items", "Accessories" },
		BuildCandidatePaths = _BuildDefaultFallbackPaths,
		Materialize = _CloneModel,
	},
}

function RenderAssetFamilyConfig.GetConfig(familyId: TRenderAssetFamilyId): TRenderAssetFamilyConfig
	local config = FAMILY_CONFIGS[familyId]
	assert(config ~= nil, `RenderAssetFamilyConfig: unsupported family "{familyId}"`)
	return config
end

function RenderAssetFamilyConfig.GetConfigs(): { [TRenderAssetFamilyId]: TRenderAssetFamilyConfig }
	return FAMILY_CONFIGS
end

return table.freeze(RenderAssetFamilyConfig)
