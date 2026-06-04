--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RenderAssetFamilyConfig = require(script.Parent.RenderAssetFamilyConfig)

type TRenderAssetFamilyId = RenderAssetFamilyConfig.TRenderAssetFamilyId
type TRenderAssetResolveOptions = RenderAssetFamilyConfig.TRenderAssetResolveOptions
type TRenderAssetResolveResult = RenderAssetFamilyConfig.TRenderAssetResolveResult
type TRenderAssetFamilyConfig = RenderAssetFamilyConfig.TRenderAssetFamilyConfig

export type TRenderAssetResolver = {
	GetAssetsRoot: (self: TRenderAssetResolver) -> Folder?,
	ResolveAsset: (
		self: TRenderAssetResolver,
		familyId: TRenderAssetFamilyId,
		key: string,
		options: TRenderAssetResolveOptions?
	) -> TRenderAssetResolveResult?,
	AssetExists: (
		self: TRenderAssetResolver,
		familyId: TRenderAssetFamilyId,
		key: string,
		options: TRenderAssetResolveOptions?
	) -> boolean,
	GetStructureModel: (self: TRenderAssetResolver, structureType: string, options: TRenderAssetResolveOptions?) -> Model?,
	StructureModelExists: (
		self: TRenderAssetResolver,
		structureType: string,
		options: TRenderAssetResolveOptions?
	) -> boolean,
	GetAnimationClip: (
		self: TRenderAssetResolver,
		actionPath: string,
		variant: string?,
		options: TRenderAssetResolveOptions?
	) -> Animation?,
	AnimationClipExists: (
		self: TRenderAssetResolver,
		actionPath: string,
		variant: string?,
		options: TRenderAssetResolveOptions?
	) -> boolean,
	GetAllAnimationClips: (
		self: TRenderAssetResolver,
		actionPath: string,
		options: TRenderAssetResolveOptions?
	) -> { [string]: Animation },
	GetSkillEffect: (self: TRenderAssetResolver, effectKey: string, options: TRenderAssetResolveOptions?) -> Folder | Model?,
	SkillEffectExists: (
		self: TRenderAssetResolver,
		effectKey: string,
		options: TRenderAssetResolveOptions?
	) -> boolean,
	GetStatusEffect: (
		self: TRenderAssetResolver,
		effectKey: string,
		options: TRenderAssetResolveOptions?
	) -> Folder | Model?,
	StatusEffectExists: (
		self: TRenderAssetResolver,
		effectKey: string,
		options: TRenderAssetResolveOptions?
	) -> boolean,
	GetCombatSound: (self: TRenderAssetResolver, soundPath: string, options: TRenderAssetResolveOptions?) -> Sound?,
	CombatSoundExists: (
		self: TRenderAssetResolver,
		soundPath: string,
		options: TRenderAssetResolveOptions?
	) -> boolean,
	GetUISound: (self: TRenderAssetResolver, soundPath: string, options: TRenderAssetResolveOptions?) -> Sound?,
	UISoundExists: (
		self: TRenderAssetResolver,
		soundPath: string,
		options: TRenderAssetResolveOptions?
	) -> boolean,
	GetToolModel: (self: TRenderAssetResolver, assetId: string, options: TRenderAssetResolveOptions?) -> Model?,
	ToolModelExists: (self: TRenderAssetResolver, assetId: string, options: TRenderAssetResolveOptions?) -> boolean,
	GetArmorModel: (self: TRenderAssetResolver, assetId: string, options: TRenderAssetResolveOptions?) -> Model?,
	ArmorModelExists: (self: TRenderAssetResolver, assetId: string, options: TRenderAssetResolveOptions?) -> boolean,
	GetAccessoryModel: (self: TRenderAssetResolver, assetId: string, options: TRenderAssetResolveOptions?) -> Model?,
	AccessoryModelExists: (
		self: TRenderAssetResolver,
		assetId: string,
		options: TRenderAssetResolveOptions?
	) -> boolean,
}

local RenderAssetResolver = {}
RenderAssetResolver.__index = RenderAssetResolver

local function _NavigateToInstance(root: Instance, pathSegments: { string }): Instance?
	local current: Instance = root
	for _, segment in ipairs(pathSegments) do
		local nextInstance = current:FindFirstChild(segment)
		if nextInstance == nil then
			return nil
		end
		current = nextInstance
	end
	return current
end

local function _BuildResolvedOptions(
	options: TRenderAssetResolveOptions?,
	variant: string?
): TRenderAssetResolveOptions?
	if variant == nil then
		return options
	end

	local resolvedOptions = {}
	if options ~= nil then
		for key, value in options do
			(resolvedOptions :: any)[key] = value
		end
	end
	resolvedOptions.Variant = variant
	return resolvedOptions
end

function RenderAssetResolver.new(assetsRoot: Folder?): TRenderAssetResolver
	local self = setmetatable({}, RenderAssetResolver)
	self._assetsRoot = assetsRoot
	return self :: any
end

function RenderAssetResolver:GetAssetsRoot(): Folder?
	return self._assetsRoot
end

function RenderAssetResolver:_ResolveRoot(
	config: TRenderAssetFamilyConfig,
	options: TRenderAssetResolveOptions?
): Instance?
	if options ~= nil and options.Root ~= nil then
		return options.Root
	end
	if self._assetsRoot == nil then
		return nil
	end
	return _NavigateToInstance(self._assetsRoot, config.RootPath)
end

function RenderAssetResolver:ResolveAsset(
	familyId: TRenderAssetFamilyId,
	key: string,
	options: TRenderAssetResolveOptions?
): TRenderAssetResolveResult?
	if type(key) ~= "string" or key == "" then
		return nil
	end

	local config = RenderAssetFamilyConfig.GetConfig(familyId)
	local root = self:_ResolveRoot(config, options)
	if root == nil then
		return nil
	end

	local normalizedKey = if config.NormalizeKey ~= nil then config.NormalizeKey(key, options) else key
	local candidatePaths = config.BuildCandidatePaths(normalizedKey, options)
	for candidateIndex, candidatePath in ipairs(candidatePaths) do
		local sourceInstance = _NavigateToInstance(root, candidatePath)
		if sourceInstance == nil then
			continue
		end

		local value = config.Materialize(sourceInstance, options)
		if value ~= nil then
			return {
				FamilyId = familyId,
				Key = key,
				NormalizedKey = normalizedKey,
				SourceInstance = sourceInstance,
				UsedFallback = candidateIndex > 1,
				Value = value,
			}
		end
	end

	return nil
end

function RenderAssetResolver:AssetExists(
	familyId: TRenderAssetFamilyId,
	key: string,
	options: TRenderAssetResolveOptions?
): boolean
	return self:ResolveAsset(familyId, key, options) ~= nil
end

function RenderAssetResolver:GetStructureModel(structureType: string, options: TRenderAssetResolveOptions?): Model?
	local resolved = self:ResolveAsset("StructureModel", structureType, options)
	return if resolved ~= nil then resolved.Value else nil
end

function RenderAssetResolver:StructureModelExists(
	structureType: string,
	options: TRenderAssetResolveOptions?
): boolean
	return self:AssetExists("StructureModel", structureType, options)
end

function RenderAssetResolver:GetAnimationClip(
	actionPath: string,
	variant: string?,
	options: TRenderAssetResolveOptions?
): Animation?
	local resolved = self:ResolveAsset("AnimationClip", actionPath, _BuildResolvedOptions(options, variant))
	return if resolved ~= nil then resolved.Value else nil
end

function RenderAssetResolver:AnimationClipExists(
	actionPath: string,
	variant: string?,
	options: TRenderAssetResolveOptions?
): boolean
	return self:AssetExists("AnimationClip", actionPath, _BuildResolvedOptions(options, variant))
end

function RenderAssetResolver:GetAllAnimationClips(
	actionPath: string,
	options: TRenderAssetResolveOptions?
): { [string]: Animation }
	local config = RenderAssetFamilyConfig.GetConfig("AnimationClip")
	local root = self:_ResolveRoot(config, options)
	if root == nil then
		return {}
	end

	local actionSegments = {}
	for _, segment in ipairs(string.split(actionPath, "/")) do
		if segment ~= "" then
			table.insert(actionSegments, segment)
		end
	end

	local actionFolder = _NavigateToInstance(root, actionSegments)
	if actionFolder == nil then
		return {}
	end

	local clipsByVariant = {}
	for _, child in ipairs(actionFolder:GetChildren()) do
		if child:IsA("Folder") then
			local animation = child:FindFirstChildWhichIsA("Animation")
			if animation ~= nil then
				clipsByVariant[child.Name] = animation
			end
		end
	end

	return clipsByVariant
end

function RenderAssetResolver:GetSkillEffect(
	effectKey: string,
	options: TRenderAssetResolveOptions?
): Folder | Model?
	local resolved = self:ResolveAsset("SkillEffect", effectKey, options)
	return if resolved ~= nil then resolved.Value else nil
end

function RenderAssetResolver:SkillEffectExists(
	effectKey: string,
	options: TRenderAssetResolveOptions?
): boolean
	return self:AssetExists("SkillEffect", effectKey, options)
end

function RenderAssetResolver:GetStatusEffect(
	effectKey: string,
	options: TRenderAssetResolveOptions?
): Folder | Model?
	local resolved = self:ResolveAsset("StatusEffect", effectKey, options)
	return if resolved ~= nil then resolved.Value else nil
end

function RenderAssetResolver:StatusEffectExists(
	effectKey: string,
	options: TRenderAssetResolveOptions?
): boolean
	return self:AssetExists("StatusEffect", effectKey, options)
end

function RenderAssetResolver:GetCombatSound(soundPath: string, options: TRenderAssetResolveOptions?): Sound?
	local resolved = self:ResolveAsset("CombatSound", soundPath, options)
	return if resolved ~= nil then resolved.Value else nil
end

function RenderAssetResolver:CombatSoundExists(
	soundPath: string,
	options: TRenderAssetResolveOptions?
): boolean
	return self:AssetExists("CombatSound", soundPath, options)
end

function RenderAssetResolver:GetUISound(soundPath: string, options: TRenderAssetResolveOptions?): Sound?
	local resolved = self:ResolveAsset("UISound", soundPath, options)
	return if resolved ~= nil then resolved.Value else nil
end

function RenderAssetResolver:UISoundExists(
	soundPath: string,
	options: TRenderAssetResolveOptions?
): boolean
	return self:AssetExists("UISound", soundPath, options)
end

function RenderAssetResolver:GetToolModel(assetId: string, options: TRenderAssetResolveOptions?): Model?
	local resolved = self:ResolveAsset("ToolModel", assetId, options)
	return if resolved ~= nil then resolved.Value else nil
end

function RenderAssetResolver:ToolModelExists(assetId: string, options: TRenderAssetResolveOptions?): boolean
	return self:AssetExists("ToolModel", assetId, options)
end

function RenderAssetResolver:GetArmorModel(assetId: string, options: TRenderAssetResolveOptions?): Model?
	local resolved = self:ResolveAsset("ArmorModel", assetId, options)
	return if resolved ~= nil then resolved.Value else nil
end

function RenderAssetResolver:ArmorModelExists(assetId: string, options: TRenderAssetResolveOptions?): boolean
	return self:AssetExists("ArmorModel", assetId, options)
end

function RenderAssetResolver:GetAccessoryModel(assetId: string, options: TRenderAssetResolveOptions?): Model?
	local resolved = self:ResolveAsset("AccessoryModel", assetId, options)
	return if resolved ~= nil then resolved.Value else nil
end

function RenderAssetResolver:AccessoryModelExists(assetId: string, options: TRenderAssetResolveOptions?): boolean
	return self:AssetExists("AccessoryModel", assetId, options)
end

return RenderAssetResolver
