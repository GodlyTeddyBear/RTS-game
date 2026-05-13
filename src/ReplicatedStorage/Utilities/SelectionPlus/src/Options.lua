--!strict

local SpatialQuery = require(script.Parent.Parent.Parent.SpatialQuery)
local Types = require(script.Parent.Types)

type THighlightConfig = Types.THighlightConfig
type TRadiusConfig = Types.TRadiusConfig
type TSelectionManagerConfig = Types.TSelectionManagerConfig
type TSelectionRequest = Types.TSelectionRequest
type TSelectionResolverOptions = Types.TSelectionResolverOptions
type TSelectionSetRequest = Types.TSelectionSetRequest

local Options = {}

local function _CloneDictionary(value: { [string]: any }?): { [string]: any }?
	if value == nil then
		return nil
	end

	return table.clone(value)
end

function Options.CreateResolverOptions(spec: TSelectionResolverOptions?): TSelectionResolverOptions?
	if spec == nil then
		return nil
	end

	return {
		RayLength = spec.RayLength,
		QueryOptions = if spec.QueryOptions ~= nil then SpatialQuery.MergeOptions(nil, spec.QueryOptions) else nil,
		AdorneeSelector = spec.AdorneeSelector,
		WorldPositionSelector = spec.WorldPositionSelector,
		ResolveRoot = spec.ResolveRoot,
		ResolveAdornee = spec.ResolveAdornee,
		ResolveWorldPosition = spec.ResolveWorldPosition,
	}
end

function Options.MergeResolverOptions(
	baseOptions: TSelectionResolverOptions?,
	overrideOptions: TSelectionResolverOptions?
): TSelectionResolverOptions?
	if baseOptions == nil and overrideOptions == nil then
		return nil
	end

	local merged = Options.CreateResolverOptions(baseOptions) or {}
	local overrides = Options.CreateResolverOptions(overrideOptions)
	if overrides == nil then
		return merged
	end

	if merged.QueryOptions ~= nil or overrides.QueryOptions ~= nil then
		merged.QueryOptions = SpatialQuery.MergeOptions(merged.QueryOptions, overrides.QueryOptions)
		overrides.QueryOptions = nil
	end

	for key, value in pairs(overrides) do
		(merged :: any)[key] = value
	end

	return merged
end

function Options.CreateHighlightOptions(spec: THighlightConfig?): THighlightConfig?
	if spec == nil then
		return nil
	end

	return {
		Enabled = spec.Enabled,
		FillColor = spec.FillColor,
		OutlineColor = spec.OutlineColor,
		FillTransparency = spec.FillTransparency,
		OutlineTransparency = spec.OutlineTransparency,
		DepthMode = spec.DepthMode,
		Parent = spec.Parent,
		Adornee = spec.Adornee,
		BuildVisual = spec.BuildVisual,
	}
end

function Options.MergeHighlightOptions(baseOptions: THighlightConfig?, overrideOptions: THighlightConfig?): THighlightConfig?
	if baseOptions == nil and overrideOptions == nil then
		return nil
	end

	local merged = Options.CreateHighlightOptions(baseOptions) or {}
	local overrides = Options.CreateHighlightOptions(overrideOptions)
	if overrides == nil then
		return merged
	end

	for key, value in pairs(overrides) do
		(merged :: any)[key] = value
	end

	return merged
end

function Options.CreateRadiusOptions(spec: TRadiusConfig?): TRadiusConfig?
	if spec == nil then
		return nil
	end

	return {
		Enabled = spec.Enabled,
		Radius = spec.Radius,
		Height = spec.Height,
		Color = spec.Color,
		Transparency = spec.Transparency,
		ClampToGround = spec.ClampToGround,
		Offset = spec.Offset,
		Parent = spec.Parent,
		QueryOptions = if spec.QueryOptions ~= nil then SpatialQuery.MergeOptions(nil, spec.QueryOptions) else nil,
		BuildVisual = spec.BuildVisual,
	}
end

function Options.MergeRadiusOptions(baseOptions: TRadiusConfig?, overrideOptions: TRadiusConfig?): TRadiusConfig?
	if baseOptions == nil and overrideOptions == nil then
		return nil
	end

	local merged = Options.CreateRadiusOptions(baseOptions) or {}
	local overrides = Options.CreateRadiusOptions(overrideOptions)
	if overrides == nil then
		return merged
	end

	if merged.QueryOptions ~= nil or overrides.QueryOptions ~= nil then
		merged.QueryOptions = SpatialQuery.MergeOptions(merged.QueryOptions, overrides.QueryOptions)
		overrides.QueryOptions = nil
	end

	for key, value in pairs(overrides) do
		(merged :: any)[key] = value
	end

	return merged
end

function Options.CreateRequest(spec: TSelectionRequest?): TSelectionRequest
	if spec == nil then
		return {
			Target = nil,
			ResolverOptions = nil,
			Highlight = nil,
			Radius = nil,
			Metadata = nil,
		}
	end

	return {
		Target = spec.Target,
		ResolverOptions = Options.CreateResolverOptions(spec.ResolverOptions),
		Highlight = Options.CreateHighlightOptions(spec.Highlight),
		Radius = Options.CreateRadiusOptions(spec.Radius),
		Metadata = _CloneDictionary(spec.Metadata),
	}
end

function Options.CreateSetRequest(spec: TSelectionSetRequest?): TSelectionSetRequest
	if spec == nil then
		return {
			Targets = nil,
			ResolverOptions = nil,
			Highlight = nil,
			Radius = nil,
			Metadata = nil,
		}
	end

	return {
		Targets = if spec.Targets ~= nil then table.clone(spec.Targets) else nil,
		ResolverOptions = Options.CreateResolverOptions(spec.ResolverOptions),
		Highlight = Options.CreateHighlightOptions(spec.Highlight),
		Radius = Options.CreateRadiusOptions(spec.Radius),
		Metadata = _CloneDictionary(spec.Metadata),
	}
end

function Options.CreateManagerConfig(spec: TSelectionManagerConfig?): TSelectionManagerConfig
	if spec == nil then
		return {}
	end

	return {
		Parent = spec.Parent,
		Name = spec.Name,
		DefaultResolverOptions = Options.CreateResolverOptions(spec.DefaultResolverOptions),
		DefaultHighlight = Options.CreateHighlightOptions(spec.DefaultHighlight),
		DefaultRadius = Options.CreateRadiusOptions(spec.DefaultRadius),
	}
end

return table.freeze(Options)
