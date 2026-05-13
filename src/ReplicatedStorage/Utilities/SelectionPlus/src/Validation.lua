--!strict

local SpatialQuery = require(script.Parent.Parent.Parent.SpatialQuery)
local Enums = require(script.Parent.Enums)
local Options = require(script.Parent.Options)
local Types = require(script.Parent.Types)

type THighlightConfig = Types.THighlightConfig
type TRadiusConfig = Types.TRadiusConfig
type TResolvedSelectionManagerConfig = Types.TResolvedSelectionManagerConfig
type TResolvedSelectionRequest = Types.TResolvedSelectionRequest
type TResolvedSelectionSetRequest = Types.TResolvedSelectionSetRequest
type TResolvedSelectionTarget = Types.TResolvedSelectionTarget
type TSelectionEntry = Types.TSelectionEntry
type TSelectionManagerConfig = Types.TSelectionManagerConfig
type TSelectionMode = Types.TSelectionMode
type TSelectionRequest = Types.TSelectionRequest
type TSelectionResolverOptions = Types.TSelectionResolverOptions
type TSelectionSetRequest = Types.TSelectionSetRequest
type TSelectionSnapshot = Types.TSelectionSnapshot
type TSelectionTargetLike = Types.TSelectionTargetLike

local Validation = {}

local DEFAULT_MANAGER_NAME = "ClientSelectionPlus"
local DEFAULT_FILL_COLOR = Color3.fromRGB(255, 221, 87)
local DEFAULT_OUTLINE_COLOR = Color3.fromRGB(255, 255, 255)
local DEFAULT_RADIUS_COLOR = Color3.fromRGB(255, 152, 61)

function Validation.IsResolvedTarget(value: any): boolean
	if type(value) ~= "table" then
		return false
	end

	return typeof(value.Root) == "Instance"
		and typeof(value.Adornee) == "Instance"
		and typeof(value.WorldPosition) == "Vector3"
end

function Validation.AssertResolvedTarget(target: TResolvedSelectionTarget)
	assert(typeof(target.Root) == "Instance" and target.Root.Parent ~= nil, "SelectionPlus resolved target requires Root")
	assert(typeof(target.Adornee) == "Instance", "SelectionPlus resolved target requires Adornee")
	assert(typeof(target.WorldPosition) == "Vector3", "SelectionPlus resolved target requires WorldPosition")

	local adorneeInstance = target.Adornee
	assert(
		adorneeInstance:IsA("Model") or adorneeInstance:IsA("BasePart"),
		"SelectionPlus Adornee must be a Model or BasePart"
	)
end

function Validation.CloneFrozenDictionary(value: { [string]: any }?): { [string]: any }?
	if value == nil then
		return nil
	end

	return table.freeze(table.clone(value))
end

function Validation.NormalizeResolverOptions(options: TSelectionResolverOptions?): TSelectionResolverOptions?
	if options == nil then
		return nil
	end

	local normalizedOptions = Options.CreateResolverOptions(options) :: TSelectionResolverOptions
	if normalizedOptions.QueryOptions ~= nil then
		normalizedOptions.QueryOptions = SpatialQuery.MergeOptions(nil, normalizedOptions.QueryOptions)
	end

	return table.freeze(normalizedOptions)
end

function Validation.NormalizeHighlightOptions(
	config: THighlightConfig?,
	defaults: THighlightConfig?
): THighlightConfig?
	if config == nil and defaults == nil then
		config = {}
	end

	local mergedConfig = Options.MergeHighlightOptions(defaults, config)
	if mergedConfig == nil then
		return nil
	end

	local normalizedConfig: THighlightConfig = {
		Enabled = true,
		FillColor = DEFAULT_FILL_COLOR,
		OutlineColor = DEFAULT_OUTLINE_COLOR,
		FillTransparency = 0.75,
		OutlineTransparency = 0,
		DepthMode = Enum.HighlightDepthMode.AlwaysOnTop,
		Parent = nil,
		Adornee = nil,
		BuildVisual = nil,
	}

	for key, value in pairs(mergedConfig) do
		(normalizedConfig :: any)[key] = value
	end

	return table.freeze(normalizedConfig)
end

function Validation.NormalizeRadiusOptions(config: TRadiusConfig?, defaults: TRadiusConfig?): TRadiusConfig?
	if config == nil and defaults == nil then
		return nil
	end

	local mergedConfig = Options.MergeRadiusOptions(defaults, config)
	if mergedConfig == nil then
		return nil
	end

	local normalizedConfig: TRadiusConfig = {
		Enabled = true,
		Radius = 0,
		Height = 0.2,
		Color = DEFAULT_RADIUS_COLOR,
		Transparency = 0.7,
		ClampToGround = true,
		Offset = Vector3.zero,
		Parent = nil,
		QueryOptions = nil,
		BuildVisual = nil,
	}

	for key, value in pairs(mergedConfig) do
		(normalizedConfig :: any)[key] = value
	end

	if normalizedConfig.QueryOptions ~= nil then
		normalizedConfig.QueryOptions = SpatialQuery.MergeOptions(nil, normalizedConfig.QueryOptions)
	end

	if normalizedConfig.Radius == nil or normalizedConfig.Radius <= 0 then
		return nil
	end

	return table.freeze(normalizedConfig)
end

function Validation.NormalizeManagerConfig(config: TSelectionManagerConfig?): TResolvedSelectionManagerConfig
	local normalizedConfig = Options.CreateManagerConfig(config)

	return table.freeze({
		Parent = normalizedConfig.Parent,
		Name = if normalizedConfig.Name ~= nil then normalizedConfig.Name else DEFAULT_MANAGER_NAME,
		DefaultResolverOptions = Validation.NormalizeResolverOptions(normalizedConfig.DefaultResolverOptions),
		DefaultHighlight = Validation.NormalizeHighlightOptions(normalizedConfig.DefaultHighlight, nil),
		DefaultRadius = Validation.NormalizeRadiusOptions(normalizedConfig.DefaultRadius, nil),
	})
end

function Validation.ResolveRequest(
	managerConfig: TResolvedSelectionManagerConfig,
	request: TSelectionRequest?
): TResolvedSelectionRequest
	local mutableRequest = Options.CreateRequest(request)

	return table.freeze({
		Target = mutableRequest.Target,
		ResolverOptions = Validation.NormalizeResolverOptions(
			Options.MergeResolverOptions(managerConfig.DefaultResolverOptions, mutableRequest.ResolverOptions)
		),
		Highlight = Validation.NormalizeHighlightOptions(mutableRequest.Highlight, managerConfig.DefaultHighlight),
		Radius = Validation.NormalizeRadiusOptions(mutableRequest.Radius, managerConfig.DefaultRadius),
		Metadata = Validation.CloneFrozenDictionary(mutableRequest.Metadata),
	})
end

function Validation.ResolveSetRequest(
	managerConfig: TResolvedSelectionManagerConfig,
	request: TSelectionSetRequest?
): TResolvedSelectionSetRequest
	local mutableRequest = Options.CreateSetRequest(request)

	return table.freeze({
		Targets = if mutableRequest.Targets ~= nil then table.freeze(table.clone(mutableRequest.Targets)) else table.freeze({}),
		ResolverOptions = Validation.NormalizeResolverOptions(
			Options.MergeResolverOptions(managerConfig.DefaultResolverOptions, mutableRequest.ResolverOptions)
		),
		Highlight = Validation.NormalizeHighlightOptions(mutableRequest.Highlight, managerConfig.DefaultHighlight),
		Radius = Validation.NormalizeRadiusOptions(mutableRequest.Radius, managerConfig.DefaultRadius),
		Metadata = Validation.CloneFrozenDictionary(mutableRequest.Metadata),
	})
end

function Validation.CloneRequest(request: TSelectionRequest?): TSelectionRequest
	return Options.CreateRequest(request)
end

function Validation.CreateSnapshot(
	channelName: string,
	mode: TSelectionMode,
	targets: { TResolvedSelectionTarget },
	metadata: { [string]: any }?
): TSelectionSnapshot
	local entries = {}
	local seenRoots = {}

	for _, target in ipairs(targets) do
		Validation.AssertResolvedTarget(target)
		if seenRoots[target.Root] ~= true then
			seenRoots[target.Root] = true
			table.insert(entries, table.freeze({
				Key = target.Root,
				Target = target,
			} :: TSelectionEntry))
		end
	end

	return table.freeze({
		Channel = channelName,
		Mode = mode,
		Entries = table.freeze(entries),
		PrimaryEntry = entries[1],
		Metadata = metadata,
	})
end

function Validation.ResolvePrimaryTarget(snapshot: TSelectionSnapshot?): TResolvedSelectionTarget?
	if snapshot == nil or snapshot.PrimaryEntry == nil then
		return nil
	end

	return snapshot.PrimaryEntry.Target
end

function Validation.IsTargetUsable(target: TSelectionTargetLike?): boolean
	if target == nil then
		return false
	end

	if Validation.IsResolvedTarget(target) then
		return true
	end

	return typeof(target) == "Instance"
end

function Validation.CallerClearedReason()
	return Enums.InvalidationReason.CallerCleared
end

return table.freeze(Validation)
