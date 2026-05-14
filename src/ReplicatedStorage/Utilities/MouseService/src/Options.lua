--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SpatialQuery = require(ReplicatedStorage.Utilities.SpatialQuery)

local Enums = require(script.Parent.Enums)
local Types = require(script.Parent.Types)

type TMouseDragRequest = Types.TMouseDragRequest
type TMouseGestureRequest = Types.TMouseGestureRequest
type THoverRequest = Types.THoverRequest
type TMouseManagerConfig = Types.TMouseManagerConfig
type TMouseRequest = Types.TMouseRequest
type TMouseSelectionRequest = Types.TMouseSelectionRequest
type TProjectionPlane = Types.TProjectionPlane
type TResolvedHoverRequest = Types.TResolvedHoverRequest
type TResolvedMouseDragRequest = Types.TResolvedMouseDragRequest
type TResolvedMouseGestureRequest = Types.TResolvedMouseGestureRequest
type TResolvedMouseRequest = Types.TResolvedMouseRequest
type TResolvedMouseSelectionRequest = Types.TResolvedMouseSelectionRequest

local DEFAULT_RAY_LENGTH = 2000
local DEFAULT_CLICK_MAX_MOVEMENT = 6
local DEFAULT_DOUBLE_CLICK_WINDOW = 0.3
local DEFAULT_DOUBLE_CLICK_MAX_MOVEMENT = 8
local DEFAULT_HOLD_DURATION = 0.4
local DEFAULT_DRAG_START_THRESHOLD = 8
local DEFAULT_ENABLED_BUTTONS = table.freeze({
	Enums.MouseButton.Left,
	Enums.MouseButton.Right,
})

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

local function _CloneEnabledButtons(value: { Types.TMouseButton }?): { Types.TMouseButton }?
	if value == nil then
		return nil
	end

	return table.clone(value)
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
		DefaultEnabledButtons = _CloneEnabledButtons(config.DefaultEnabledButtons),
		ClickMaxMovement = config.ClickMaxMovement,
		DoubleClickWindow = config.DoubleClickWindow,
		DoubleClickMaxMovement = config.DoubleClickMaxMovement,
		HoldDuration = config.HoldDuration,
		DragStartThreshold = config.DragStartThreshold,
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
			DragMode = nil,
			PreviewSelectionChannel = nil,
			MirrorPreviewSelection = nil,
			MarqueeQueryOptions = nil,
			MarqueeSelectionOptions = nil,
			MarqueeMetadata = nil,
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
		DragMode = request.DragMode,
		PreviewSelectionChannel = request.PreviewSelectionChannel,
		MirrorPreviewSelection = request.MirrorPreviewSelection,
		MarqueeQueryOptions = if request.MarqueeQueryOptions ~= nil
			then SpatialQuery.MergeOptions(nil, request.MarqueeQueryOptions)
			else nil,
		MarqueeSelectionOptions = _CloneSelectionOptions(request.MarqueeSelectionOptions),
		MarqueeMetadata = _CloneDictionary(request.MarqueeMetadata),
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

function Options.CreateGestureRequest(request: TMouseGestureRequest?): TMouseGestureRequest
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
			EnabledButtons = nil,
			ClickMaxMovement = nil,
			DoubleClickWindow = nil,
			DoubleClickMaxMovement = nil,
			HoldDuration = nil,
			DragStartThreshold = nil,
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
		EnabledButtons = if request.EnabledButtons ~= nil then _CloneEnabledButtons(request.EnabledButtons) else nil,
		ClickMaxMovement = request.ClickMaxMovement,
		DoubleClickWindow = request.DoubleClickWindow,
		DoubleClickMaxMovement = request.DoubleClickMaxMovement,
		HoldDuration = request.HoldDuration,
		DragStartThreshold = request.DragStartThreshold,
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
		DragMode = if resolvedDragRequest.DragMode ~= nil then resolvedDragRequest.DragMode else Enums.DragMode.World,
		PreviewSelectionChannel = resolvedDragRequest.PreviewSelectionChannel,
		MirrorPreviewSelection = if resolvedDragRequest.MirrorPreviewSelection ~= nil
			then resolvedDragRequest.MirrorPreviewSelection
			else false,
		MarqueeQueryOptions = SpatialQuery.MergeOptions(resolvedMouseRequest.QueryOptions, resolvedDragRequest.MarqueeQueryOptions),
		MarqueeSelectionOptions = _MergeSelectionOptions(
			resolvedMouseRequest.SelectionOptions,
			resolvedDragRequest.MarqueeSelectionOptions
		),
		MarqueeMetadata = resolvedDragRequest.MarqueeMetadata,
	})
end

function Options.ResolveGestureRequest(
	config: TMouseManagerConfig,
	request: TMouseGestureRequest?
): TResolvedMouseGestureRequest
	local baseConfig = Options.CreateConfig(config)
	local resolvedMouseRequest = Options.ResolveRequest(baseConfig, request)
	local resolvedGestureRequest = Options.CreateGestureRequest(request)

	return table.freeze({
		ScreenPoint = resolvedMouseRequest.ScreenPoint,
		CameraProvider = resolvedMouseRequest.CameraProvider,
		RayLength = resolvedMouseRequest.RayLength,
		ResolveTarget = true,
		QueryOptions = resolvedMouseRequest.QueryOptions,
		SelectionOptions = resolvedMouseRequest.SelectionOptions,
		ProjectionPlane = resolvedMouseRequest.ProjectionPlane,
		BaseExclude = resolvedMouseRequest.BaseExclude,
		Metadata = resolvedGestureRequest.Metadata,
		EnabledButtons = table.freeze(
			(if resolvedGestureRequest.EnabledButtons ~= nil
				then _CloneEnabledButtons(resolvedGestureRequest.EnabledButtons)
				else if baseConfig.DefaultEnabledButtons ~= nil
					then _CloneEnabledButtons(baseConfig.DefaultEnabledButtons)
					else table.clone(DEFAULT_ENABLED_BUTTONS)) :: { Types.TMouseButton }
		),
		ClickMaxMovement = if resolvedGestureRequest.ClickMaxMovement ~= nil
			then resolvedGestureRequest.ClickMaxMovement
			else if baseConfig.ClickMaxMovement ~= nil then baseConfig.ClickMaxMovement else DEFAULT_CLICK_MAX_MOVEMENT,
		DoubleClickWindow = if resolvedGestureRequest.DoubleClickWindow ~= nil
			then resolvedGestureRequest.DoubleClickWindow
			else if baseConfig.DoubleClickWindow ~= nil then baseConfig.DoubleClickWindow else DEFAULT_DOUBLE_CLICK_WINDOW,
		DoubleClickMaxMovement = if resolvedGestureRequest.DoubleClickMaxMovement ~= nil
			then resolvedGestureRequest.DoubleClickMaxMovement
			else if baseConfig.DoubleClickMaxMovement ~= nil
				then baseConfig.DoubleClickMaxMovement
				else DEFAULT_DOUBLE_CLICK_MAX_MOVEMENT,
		HoldDuration = if resolvedGestureRequest.HoldDuration ~= nil
			then resolvedGestureRequest.HoldDuration
			else if baseConfig.HoldDuration ~= nil then baseConfig.HoldDuration else DEFAULT_HOLD_DURATION,
		DragStartThreshold = if resolvedGestureRequest.DragStartThreshold ~= nil
			then resolvedGestureRequest.DragStartThreshold
			else if baseConfig.DragStartThreshold ~= nil then baseConfig.DragStartThreshold else DEFAULT_DRAG_START_THRESHOLD,
	})
end

return table.freeze(Options)
