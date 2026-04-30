--!strict

local Types = require(script.Parent.Types)

type THighlightConfig = Types.THighlightConfig
type TRadiusConfig = Types.TRadiusConfig
type TResolvedSelectionTarget = Types.TResolvedSelectionTarget
type TSelectionManagerConfig = Types.TSelectionManagerConfig
type TSelectionRequest = Types.TSelectionRequest
type TSelectionResolverOptions = Types.TSelectionResolverOptions

--[=[
    @class SelectionPlusValidation
    Shared normalization and guard helpers for the `SelectionPlus` package.
    @client
]=]
local Validation = {}

local DEFAULT_MANAGER_NAME = "ClientSelectionPlus"
local DEFAULT_FILL_COLOR = Color3.fromRGB(255, 221, 87)
local DEFAULT_OUTLINE_COLOR = Color3.fromRGB(255, 255, 255)
local DEFAULT_RADIUS_COLOR = Color3.fromRGB(255, 152, 61)

local _ApplyHighlightConfig: (target: THighlightConfig, source: THighlightConfig?) -> ()
local _ApplyRadiusConfig: (target: TRadiusConfig, source: TRadiusConfig?) -> ()

--[=[
    Returns a frozen manager config with defaults applied.
    @within SelectionPlusValidation
    @param config TSelectionManagerConfig? -- Raw manager config.
    @return TSelectionManagerConfig -- Frozen normalized manager config.
]=]
function Validation.NormalizeManagerConfig(config: TSelectionManagerConfig?): TSelectionManagerConfig
	local normalizedConfig: TSelectionManagerConfig = {
		Parent = if config ~= nil then config.Parent else nil,
		Name = if config ~= nil and config.Name ~= nil then config.Name else DEFAULT_MANAGER_NAME,
		DefaultHighlight = Validation.NormalizeHighlightConfig(if config ~= nil then config.DefaultHighlight else nil),
		DefaultRadius = Validation.NormalizeRadiusConfig(if config ~= nil then config.DefaultRadius else nil),
	}

	return table.freeze(normalizedConfig)
end

--[=[
    Returns a frozen selection request with manager defaults merged in.
    @within SelectionPlusValidation
    @param request TSelectionRequest? -- Raw selection request.
    @param managerConfig TSelectionManagerConfig -- Normalized manager defaults.
    @return TSelectionRequest -- Frozen normalized request.
]=]
function Validation.NormalizeRequest(
	request: TSelectionRequest?,
	managerConfig: TSelectionManagerConfig
): TSelectionRequest
	local resolverOptions = Validation.NormalizeResolverOptions(if request ~= nil then request.ResolverOptions else nil)
	local metadata = Validation.CloneFrozenDictionary(if request ~= nil then request.Metadata else nil)
	local normalizedHighlight = Validation.NormalizeHighlightConfig(
		if request ~= nil then request.Highlight else nil,
		managerConfig.DefaultHighlight
	)
	local normalizedRadius = Validation.NormalizeRadiusConfig(
		if request ~= nil then request.Radius else nil,
		managerConfig.DefaultRadius
	)

	return table.freeze({
		Target = if request ~= nil then request.Target else nil,
		ResolverOptions = resolverOptions,
		Highlight = normalizedHighlight,
		Radius = normalizedRadius,
		Metadata = metadata,
	})
end

--[=[
    Returns a shallow-cloned request table suitable for temporary call-site edits.
    @within SelectionPlusValidation
    @param request TSelectionRequest? -- Source request.
    @return TSelectionRequest -- Cloned request table.
]=]
function Validation.CloneRequest(request: TSelectionRequest?): TSelectionRequest
	if request == nil then
		return {
			Target = nil,
			ResolverOptions = nil,
			Highlight = nil,
			Radius = nil,
			Metadata = nil,
		}
	end

	return {
		Target = request.Target,
		ResolverOptions = request.ResolverOptions,
		Highlight = request.Highlight,
		Radius = request.Radius,
		Metadata = request.Metadata,
	}
end

--[=[
    Validates a channel name before it is used by a manager.
    @within SelectionPlusValidation
    @param channelName string -- Channel name to validate.
    @error string -- Thrown when the channel name is empty.
]=]
function Validation.AssertChannelName(channelName: string)
	assert(channelName ~= "", "SelectionPlus channelName must not be empty")
end

--[=[
    Validates a resolved selection target shape.
    @within SelectionPlusValidation
    @param target TResolvedSelectionTarget -- Target to validate.
    @error string -- Thrown when required target fields are missing or invalid.
]=]
function Validation.AssertResolvedTarget(target: TResolvedSelectionTarget)
	assert(typeof(target.Root) == "Instance", "SelectionPlus resolved target requires Root")
	assert(typeof(target.Adornee) == "Instance", "SelectionPlus resolved target requires Adornee")
	assert(typeof(target.WorldPosition) == "Vector3", "SelectionPlus resolved target requires WorldPosition")

	local adorneeInstance = target.Adornee
	assert(
		adorneeInstance:IsA("Model") or adorneeInstance:IsA("BasePart"),
		"SelectionPlus Adornee must be a Model or BasePart"
	)
end

--[=[
    Returns whether the supplied value looks like a resolved selection target.
    @within SelectionPlusValidation
    @param value any -- Value to inspect.
    @return boolean -- `true` when the value matches the expected target shape.
]=]
function Validation.IsResolvedTarget(value: any): boolean
	if type(value) ~= "table" then
		return false
	end

	return typeof(value.Root) == "Instance"
		and typeof(value.Adornee) == "Instance"
		and typeof(value.WorldPosition) == "Vector3"
end

--[=[
    Returns a frozen copy of a dictionary-like table.
    @within SelectionPlusValidation
    @param value table? -- Table to clone.
    @return table? -- Frozen clone, or `nil` when no table was supplied.
]=]
function Validation.CloneFrozenDictionary(value: { [string]: any }?): { [string]: any }?
	if value == nil then
		return nil
	end

	return table.freeze(table.clone(value))
end

--[=[
    Returns a frozen resolver options table.
    @within SelectionPlusValidation
    @param options TSelectionResolverOptions? -- Raw resolver options.
    @return TSelectionResolverOptions? -- Frozen normalized resolver options.
]=]
function Validation.NormalizeResolverOptions(options: TSelectionResolverOptions?): TSelectionResolverOptions?
	if options == nil then
		return nil
	end

	local normalizedOptions: TSelectionResolverOptions = {
		RayLength = options.RayLength,
		QueryOptions = options.QueryOptions,
		AdorneeSelector = options.AdorneeSelector,
		WorldPositionSelector = options.WorldPositionSelector,
		ResolveRoot = options.ResolveRoot,
		ResolveAdornee = options.ResolveAdornee,
		ResolveWorldPosition = options.ResolveWorldPosition,
	}

	return table.freeze(normalizedOptions)
end

--[=[
    Returns a frozen highlight config with defaults applied.
    @within SelectionPlusValidation
    @param config THighlightConfig? -- Per-request config.
    @param defaults THighlightConfig? -- Manager defaults applied first.
    @return THighlightConfig -- Frozen normalized highlight config.
]=]
function Validation.NormalizeHighlightConfig(
	config: THighlightConfig?,
	defaults: THighlightConfig?
): THighlightConfig
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

	_ApplyHighlightConfig(normalizedConfig, defaults)
	_ApplyHighlightConfig(normalizedConfig, config)

	return table.freeze(normalizedConfig)
end

--[=[
    Returns a frozen radius config with defaults applied.
    @within SelectionPlusValidation
    @param config TRadiusConfig? -- Per-request config.
    @param defaults TRadiusConfig? -- Manager defaults applied first.
    @return TRadiusConfig? -- Frozen normalized radius config.
]=]
function Validation.NormalizeRadiusConfig(config: TRadiusConfig?, defaults: TRadiusConfig?): TRadiusConfig?
	if config == nil and defaults == nil then
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

	_ApplyRadiusConfig(normalizedConfig, defaults)
	_ApplyRadiusConfig(normalizedConfig, config)

	if normalizedConfig.Radius <= 0 then
		return nil
	end

	return table.freeze(normalizedConfig)
end

_ApplyHighlightConfig = function(target: THighlightConfig, source: THighlightConfig?)
	if source == nil then
		return
	end

	if source.Enabled ~= nil then
		target.Enabled = source.Enabled
	end
	if source.FillColor ~= nil then
		target.FillColor = source.FillColor
	end
	if source.OutlineColor ~= nil then
		target.OutlineColor = source.OutlineColor
	end
	if source.FillTransparency ~= nil then
		target.FillTransparency = source.FillTransparency
	end
	if source.OutlineTransparency ~= nil then
		target.OutlineTransparency = source.OutlineTransparency
	end
	if source.DepthMode ~= nil then
		target.DepthMode = source.DepthMode
	end
	if source.Parent ~= nil then
		target.Parent = source.Parent
	end
	if source.Adornee ~= nil then
		target.Adornee = source.Adornee
	end
	if source.BuildVisual ~= nil then
		target.BuildVisual = source.BuildVisual
	end
end

_ApplyRadiusConfig = function(target: TRadiusConfig, source: TRadiusConfig?)
	if source == nil then
		return
	end

	if source.Enabled ~= nil then
		target.Enabled = source.Enabled
	end
	if source.Radius ~= nil then
		target.Radius = source.Radius
	end
	if source.Height ~= nil then
		target.Height = source.Height
	end
	if source.Color ~= nil then
		target.Color = source.Color
	end
	if source.Transparency ~= nil then
		target.Transparency = source.Transparency
	end
	if source.ClampToGround ~= nil then
		target.ClampToGround = source.ClampToGround
	end
	if source.Offset ~= nil then
		target.Offset = source.Offset
	end
	if source.Parent ~= nil then
		target.Parent = source.Parent
	end
	if source.QueryOptions ~= nil then
		target.QueryOptions = source.QueryOptions
	end
	if source.BuildVisual ~= nil then
		target.BuildVisual = source.BuildVisual
	end
end

return table.freeze(Validation)
