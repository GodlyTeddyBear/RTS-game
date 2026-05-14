--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SpatialQuery = require(ReplicatedStorage.Utilities.SpatialQuery)

local Types = require(script.Parent.Types)

type TMouseDragRequest = Types.TMouseDragRequest
type THoverRequest = Types.THoverRequest
type TMouseManagerConfig = Types.TMouseManagerConfig
type TMouseRequest = Types.TMouseRequest
type TMouseSelectionRequest = Types.TMouseSelectionRequest
type TProjectionPlane = Types.TProjectionPlane
type TResolvedHoverRequest = Types.TResolvedHoverRequest
type TResolvedMouseDragRequest = Types.TResolvedMouseDragRequest
type TResolvedMouseRequest = Types.TResolvedMouseRequest
type TResolvedMouseSelectionRequest = Types.TResolvedMouseSelectionRequest

local DEFAULT_RAY_LENGTH = 2000

local Options = {}

local function _CloneArray<T>(value: { T }?): { T }
	if value == nil then
		return {}
	end

	return table.clone(value)
end

local function _CloneDictionary(value: { [string]: any }?): { [string]: any }?
	if value == nil then
		return nil
	end

	return table.freeze(table.clone(value))
end

local function _CloneProjectionPlane(value: TProjectionPlane?): TProjectionPlane?
	if value == nil then
		return nil
	end

	return {
		Point = value.Point,
		Normal = value.Normal,
	}
end

local function _CloneSelectionOptions(options: any): any
	if options == nil then
		return nil
	end

	local clonedOptions = table.clone(options)
	if clonedOptions.QueryOptions ~= nil then
		clonedOptions.QueryOptions = SpatialQuery.MergeOptions(nil, clonedOptions.QueryOptions)
	end

	return table.freeze(clonedOptions)
end

local function _MergeSelectionOptions(baseOptions: any, overrideOptions: any): any
	if baseOptions == nil and overrideOptions == nil then
		return nil
	end

	local mergedOptions = if baseOptions ~= nil then table.clone(baseOptions) else {}
	local overrides = if overrideOptions ~= nil then table.clone(overrideOptions) else {}

	if mergedOptions.QueryOptions ~= nil or overrides.QueryOptions ~= nil then
		mergedOptions.QueryOptions = SpatialQuery.MergeOptions(mergedOptions.QueryOptions, overrides.QueryOptions)
		overrides.QueryOptions = nil
	end

	for key, value in pairs(overrides) do
		mergedOptions[key] = value
	end

	return table.freeze(mergedOptions)
end

local function _CloneHighlightOptions(options: any): any
	if options == nil then
		return nil
	end

	return table.freeze(table.clone(options))
end

local function _CloneRadiusOptions(options: any): any
	if options == nil then
		return nil
	end

	local clonedOptions = table.clone(options)
	if clonedOptions.QueryOptions ~= nil then
		clonedOptions.QueryOptions = SpatialQuery.MergeOptions(nil, clonedOptions.QueryOptions)
	end

	return table.freeze(clonedOptions)
end

function Options.CreateConfig(config: TMouseManagerConfig?): TMouseManagerConfig
	if config == nil then
		return {}
	end

	return {
		CameraProvider = config.CameraProvider,
		RayLength = config.RayLength,
		ResolveTarget = config.ResolveTarget,
		QueryOptions = if config.QueryOptions ~= nil then SpatialQuery.MergeOptions(nil, config.QueryOptions) else nil,
		SelectionOptions = _CloneSelectionOptions(config.SelectionOptions),
		ProjectionPlane = _CloneProjectionPlane(config.ProjectionPlane),
		BaseExclude = _CloneArray(config.BaseExclude),
		SelectionParent = config.SelectionParent,
		MirrorSelections = config.MirrorSelections,
		DefaultSelectionHighlight = _CloneHighlightOptions(config.DefaultSelectionHighlight),
		DefaultSelectionRadius = _CloneRadiusOptions(config.DefaultSelectionRadius),
		MirrorHovers = config.MirrorHovers,
		DefaultHoverHighlight = _CloneHighlightOptions(config.DefaultHoverHighlight),
		DefaultHoverRadius = _CloneRadiusOptions(config.DefaultHoverRadius),
	}
end

function Options.CreateRequest(request: TMouseRequest?): TMouseRequest
	if request == nil then
		return {}
	end

	return {
		ScreenPoint = request.ScreenPoint,
		CameraProvider = request.CameraProvider,
		RayLength = request.RayLength,
		ResolveTarget = request.ResolveTarget,
		QueryOptions = if request.QueryOptions ~= nil then SpatialQuery.MergeOptions(nil, request.QueryOptions) else nil,
		SelectionOptions = _CloneSelectionOptions(request.SelectionOptions),
		ProjectionPlane = _CloneProjectionPlane(request.ProjectionPlane),
		BaseExclude = _CloneArray(request.BaseExclude),
	}
end

function Options.ResolveRequest(config: TMouseManagerConfig, request: TMouseRequest?): TResolvedMouseRequest
	local baseConfig = Options.CreateConfig(config)
	local overrides = Options.CreateRequest(request)

	local resolvedExclude = _CloneArray(baseConfig.BaseExclude)
	for _, instance in ipairs(_CloneArray(overrides.BaseExclude)) do
		table.insert(resolvedExclude, instance)
	end

	return table.freeze({
		ScreenPoint = overrides.ScreenPoint,
		CameraProvider = if overrides.CameraProvider ~= nil then overrides.CameraProvider else baseConfig.CameraProvider,
		RayLength = if overrides.RayLength ~= nil then overrides.RayLength else (baseConfig.RayLength or DEFAULT_RAY_LENGTH),
		ResolveTarget = if overrides.ResolveTarget ~= nil
			then overrides.ResolveTarget
			else if baseConfig.ResolveTarget ~= nil then baseConfig.ResolveTarget else true,
		QueryOptions = SpatialQuery.MergeOptions(baseConfig.QueryOptions, overrides.QueryOptions),
		SelectionOptions = _MergeSelectionOptions(baseConfig.SelectionOptions, overrides.SelectionOptions),
		ProjectionPlane = if overrides.ProjectionPlane ~= nil then overrides.ProjectionPlane else baseConfig.ProjectionPlane,
		BaseExclude = table.freeze(resolvedExclude),
	})
end

function Options.CreateSelectionRequest(request: TMouseSelectionRequest?): TMouseSelectionRequest
	local baseRequest = Options.CreateRequest(request)
	if request == nil then
		return {
			ScreenPoint = baseRequest.ScreenPoint,
			CameraProvider = baseRequest.CameraProvider,
			RayLength = baseRequest.RayLength,
			ResolveTarget = baseRequest.ResolveTarget,
			QueryOptions = baseRequest.QueryOptions,
			SelectionOptions = baseRequest.SelectionOptions,
			ProjectionPlane = baseRequest.ProjectionPlane,
			BaseExclude = baseRequest.BaseExclude,
			Metadata = nil,
			MirrorSelection = nil,
			Highlight = nil,
			Radius = nil,
		}
	end

	return {
		ScreenPoint = baseRequest.ScreenPoint,
		CameraProvider = baseRequest.CameraProvider,
		RayLength = baseRequest.RayLength,
		ResolveTarget = baseRequest.ResolveTarget,
		QueryOptions = baseRequest.QueryOptions,
		SelectionOptions = baseRequest.SelectionOptions,
		ProjectionPlane = baseRequest.ProjectionPlane,
		BaseExclude = baseRequest.BaseExclude,
		Metadata = _CloneDictionary(request.Metadata),
		MirrorSelection = request.MirrorSelection,
		Highlight = _CloneHighlightOptions(request.Highlight),
		Radius = _CloneRadiusOptions(request.Radius),
	}
end

function Options.ResolveSelectionRequest(
	config: TMouseManagerConfig,
	request: TMouseSelectionRequest?
): TResolvedMouseSelectionRequest
	local baseConfig = Options.CreateConfig(config)
	local resolvedMouseRequest = Options.ResolveRequest(baseConfig, request)
	local resolvedSelectionRequest = Options.CreateSelectionRequest(request)

	return table.freeze({
		ScreenPoint = resolvedMouseRequest.ScreenPoint,
		CameraProvider = resolvedMouseRequest.CameraProvider,
		RayLength = resolvedMouseRequest.RayLength,
		ResolveTarget = resolvedMouseRequest.ResolveTarget,
		QueryOptions = resolvedMouseRequest.QueryOptions,
		SelectionOptions = resolvedMouseRequest.SelectionOptions,
		ProjectionPlane = resolvedMouseRequest.ProjectionPlane,
		BaseExclude = resolvedMouseRequest.BaseExclude,
		Metadata = resolvedSelectionRequest.Metadata,
		MirrorSelection = if resolvedSelectionRequest.MirrorSelection ~= nil
			then resolvedSelectionRequest.MirrorSelection
			else if baseConfig.MirrorSelections ~= nil then baseConfig.MirrorSelections else false,
		Highlight = if resolvedSelectionRequest.Highlight ~= nil
			then resolvedSelectionRequest.Highlight
			else baseConfig.DefaultSelectionHighlight,
		Radius = if resolvedSelectionRequest.Radius ~= nil
			then resolvedSelectionRequest.Radius
			else baseConfig.DefaultSelectionRadius,
	})
end

function Options.CreateDragRequest(request: TMouseDragRequest?): TMouseDragRequest
	local baseRequest = Options.CreateRequest(request)
	if request == nil then
		return {
			ScreenPoint = baseRequest.ScreenPoint,
			CameraProvider = baseRequest.CameraProvider,
			RayLength = baseRequest.RayLength,
			ResolveTarget = baseRequest.ResolveTarget,
			QueryOptions = baseRequest.QueryOptions,
			SelectionOptions = baseRequest.SelectionOptions,
			ProjectionPlane = baseRequest.ProjectionPlane,
			BaseExclude = baseRequest.BaseExclude,
			Metadata = nil,
		}
	end

	return {
		ScreenPoint = baseRequest.ScreenPoint,
		CameraProvider = baseRequest.CameraProvider,
		RayLength = baseRequest.RayLength,
		ResolveTarget = baseRequest.ResolveTarget,
		QueryOptions = baseRequest.QueryOptions,
		SelectionOptions = baseRequest.SelectionOptions,
		ProjectionPlane = baseRequest.ProjectionPlane,
		BaseExclude = baseRequest.BaseExclude,
		Metadata = _CloneDictionary(request.Metadata),
	}
end

function Options.CreateHoverRequest(request: THoverRequest?): THoverRequest
	local baseRequest = Options.CreateRequest(request)
	if request == nil then
		return {
			ScreenPoint = baseRequest.ScreenPoint,
			CameraProvider = baseRequest.CameraProvider,
			RayLength = baseRequest.RayLength,
			ResolveTarget = baseRequest.ResolveTarget,
			QueryOptions = baseRequest.QueryOptions,
			SelectionOptions = baseRequest.SelectionOptions,
			ProjectionPlane = baseRequest.ProjectionPlane,
			BaseExclude = baseRequest.BaseExclude,
			Metadata = nil,
			MirrorHover = nil,
			Highlight = nil,
			Radius = nil,
		}
	end

	return {
		ScreenPoint = baseRequest.ScreenPoint,
		CameraProvider = baseRequest.CameraProvider,
		RayLength = baseRequest.RayLength,
		ResolveTarget = baseRequest.ResolveTarget,
		QueryOptions = baseRequest.QueryOptions,
		SelectionOptions = baseRequest.SelectionOptions,
		ProjectionPlane = baseRequest.ProjectionPlane,
		BaseExclude = baseRequest.BaseExclude,
		Metadata = _CloneDictionary(request.Metadata),
		MirrorHover = request.MirrorHover,
		Highlight = _CloneHighlightOptions(request.Highlight),
		Radius = _CloneRadiusOptions(request.Radius),
	}
end

function Options.ResolveHoverRequest(config: TMouseManagerConfig, request: THoverRequest?): TResolvedHoverRequest
	local baseConfig = Options.CreateConfig(config)
	local resolvedMouseRequest = Options.ResolveRequest(baseConfig, request)
	local resolvedHoverRequest = Options.CreateHoverRequest(request)

	return table.freeze({
		ScreenPoint = resolvedMouseRequest.ScreenPoint,
		CameraProvider = resolvedMouseRequest.CameraProvider,
		RayLength = resolvedMouseRequest.RayLength,
		ResolveTarget = true,
		QueryOptions = resolvedMouseRequest.QueryOptions,
		SelectionOptions = resolvedMouseRequest.SelectionOptions,
		ProjectionPlane = resolvedMouseRequest.ProjectionPlane,
		BaseExclude = resolvedMouseRequest.BaseExclude,
		Metadata = resolvedHoverRequest.Metadata,
		MirrorHover = if resolvedHoverRequest.MirrorHover ~= nil
			then resolvedHoverRequest.MirrorHover
			else if baseConfig.MirrorHovers ~= nil then baseConfig.MirrorHovers else false,
		Highlight = if resolvedHoverRequest.Highlight ~= nil
			then resolvedHoverRequest.Highlight
			else baseConfig.DefaultHoverHighlight,
		Radius = if resolvedHoverRequest.Radius ~= nil
			then resolvedHoverRequest.Radius
			else baseConfig.DefaultHoverRadius,
	})
end

function Options.ResolveDragRequest(config: TMouseManagerConfig, request: TMouseDragRequest?): TResolvedMouseDragRequest
	local resolvedMouseRequest = Options.ResolveRequest(config, request)
	local resolvedDragRequest = Options.CreateDragRequest(request)

	return table.freeze({
		ScreenPoint = resolvedMouseRequest.ScreenPoint,
		CameraProvider = resolvedMouseRequest.CameraProvider,
		RayLength = resolvedMouseRequest.RayLength,
		ResolveTarget = resolvedMouseRequest.ResolveTarget,
		QueryOptions = resolvedMouseRequest.QueryOptions,
		SelectionOptions = resolvedMouseRequest.SelectionOptions,
		ProjectionPlane = resolvedMouseRequest.ProjectionPlane,
		BaseExclude = resolvedMouseRequest.BaseExclude,
		Metadata = resolvedDragRequest.Metadata,
	})
end

return table.freeze(Options)
