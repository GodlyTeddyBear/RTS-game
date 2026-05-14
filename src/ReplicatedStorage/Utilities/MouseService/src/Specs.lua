--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Specification = require(ReplicatedStorage.Utilities.Specification)

local Enums = require(script.Parent.Enums)

local Specs = {}

local function _ErrorName(errorKey: any): string
	return errorKey.Name
end

function Specs.IsValidConfig(config: any): boolean
	return config == nil or type(config) == "table"
end

function Specs.IsValidRequest(request: any): boolean
	return request == nil or type(request) == "table"
end

function Specs.IsValidChannelName(channelName: any): boolean
	return type(channelName) == "string" and channelName ~= ""
end

function Specs.IsValidScreenPoint(screenPoint: any): boolean
	return screenPoint == nil or typeof(screenPoint) == "Vector2"
end

function Specs.IsValidCameraProvider(cameraProvider: any): boolean
	return cameraProvider == nil or type(cameraProvider) == "function"
end

function Specs.IsValidRayLength(rayLength: any): boolean
	return rayLength == nil or (type(rayLength) == "number" and rayLength > 0)
end

function Specs.IsValidResolveTarget(resolveTarget: any): boolean
	return resolveTarget == nil or type(resolveTarget) == "boolean"
end

function Specs.IsValidDragMode(dragMode: any): boolean
	return dragMode == nil or dragMode == Enums.DragMode.World or dragMode == Enums.DragMode.Marquee
end

function Specs.IsValidQueryOptions(queryOptions: any): boolean
	return queryOptions == nil or type(queryOptions) == "table"
end

function Specs.IsValidSelectionOptions(selectionOptions: any): boolean
	return selectionOptions == nil or type(selectionOptions) == "table"
end

function Specs.IsValidProjectionPlane(projectionPlane: any): boolean
	return projectionPlane == nil
		or (
			type(projectionPlane) == "table"
			and typeof(projectionPlane.Point) == "Vector3"
			and typeof(projectionPlane.Normal) == "Vector3"
			and projectionPlane.Normal.Magnitude > 0
		)
end

function Specs.IsValidBaseExclude(baseExclude: any): boolean
	if baseExclude == nil then
		return true
	end

	if type(baseExclude) ~= "table" then
		return false
	end

	for index, instance in ipairs(baseExclude) do
		if type(index) ~= "number" or typeof(instance) ~= "Instance" then
			return false
		end
	end

	return true
end

function Specs.IsValidMetadata(metadata: any): boolean
	return metadata == nil or type(metadata) == "table"
end

function Specs.IsValidMirrorSelection(mirrorSelection: any): boolean
	return mirrorSelection == nil or type(mirrorSelection) == "boolean"
end

function Specs.IsValidMirrorHover(mirrorHover: any): boolean
	return mirrorHover == nil or type(mirrorHover) == "boolean"
end

function Specs.IsValidMirrorPreviewSelection(mirrorPreviewSelection: any): boolean
	return mirrorPreviewSelection == nil or type(mirrorPreviewSelection) == "boolean"
end

function Specs.IsValidPreviewSelectionChannel(previewSelectionChannel: any): boolean
	return previewSelectionChannel == nil or Specs.IsValidChannelName(previewSelectionChannel)
end

function Specs.IsValidHighlightOptions(highlight: any): boolean
	return highlight == nil or type(highlight) == "table"
end

function Specs.IsValidRadiusOptions(radius: any): boolean
	return radius == nil or type(radius) == "table"
end

function Specs.IsClientRuntime(isClient: boolean): boolean
	return isClient
end

function Specs.HasCamera(camera: Camera?): boolean
	return camera ~= nil
end

function Specs.IsServiceAlive(isDestroyed: boolean): boolean
	return not isDestroyed
end

function Specs.CanBeginDrag(hasSession: boolean): boolean
	return not hasSession
end

function Specs.CanOperateOnDrag(hasSession: boolean): boolean
	return hasSession
end

function Specs.CanBeginHover(hasSession: boolean): boolean
	return not hasSession
end

function Specs.CanOperateOnHover(hasSession: boolean): boolean
	return hasSession
end

local HasValidConfig = Specification.new(
	_ErrorName(Enums.ErrorKey.InvalidConfig),
	Enums.ErrorMessage[Enums.ErrorKey.InvalidConfig],
	function(candidate): boolean
		return Specs.IsValidConfig(candidate.Config)
	end
)

local HasValidRequest = Specification.new(
	_ErrorName(Enums.ErrorKey.InvalidRequest),
	Enums.ErrorMessage[Enums.ErrorKey.InvalidRequest],
	function(candidate): boolean
		return Specs.IsValidRequest(candidate.Request)
	end
)

local HasValidChannelName = Specification.new(
	_ErrorName(Enums.ErrorKey.InvalidChannelName),
	Enums.ErrorMessage[Enums.ErrorKey.InvalidChannelName],
	function(candidate): boolean
		return Specs.IsValidChannelName(candidate.ChannelName)
	end
)

local HasValidScreenPoint = Specification.new(
	_ErrorName(Enums.ErrorKey.InvalidScreenPoint),
	Enums.ErrorMessage[Enums.ErrorKey.InvalidScreenPoint],
	function(candidate): boolean
		return Specs.IsValidScreenPoint(candidate.ScreenPoint)
	end
)

local HasValidCameraProvider = Specification.new(
	_ErrorName(Enums.ErrorKey.InvalidCameraProvider),
	Enums.ErrorMessage[Enums.ErrorKey.InvalidCameraProvider],
	function(candidate): boolean
		return Specs.IsValidCameraProvider(candidate.CameraProvider)
	end
)

local HasValidRayLength = Specification.new(
	_ErrorName(Enums.ErrorKey.InvalidRayLength),
	Enums.ErrorMessage[Enums.ErrorKey.InvalidRayLength],
	function(candidate): boolean
		return Specs.IsValidRayLength(candidate.RayLength)
	end
)

local HasValidResolveTarget = Specification.new(
	_ErrorName(Enums.ErrorKey.InvalidResolveTarget),
	Enums.ErrorMessage[Enums.ErrorKey.InvalidResolveTarget],
	function(candidate): boolean
		return Specs.IsValidResolveTarget(candidate.ResolveTarget)
	end
)

local HasValidDragMode = Specification.new(
	_ErrorName(Enums.ErrorKey.InvalidDragMode),
	Enums.ErrorMessage[Enums.ErrorKey.InvalidDragMode],
	function(candidate): boolean
		return Specs.IsValidDragMode(candidate.DragMode)
	end
)

local HasValidQueryOptions = Specification.new(
	_ErrorName(Enums.ErrorKey.InvalidQueryOptions),
	Enums.ErrorMessage[Enums.ErrorKey.InvalidQueryOptions],
	function(candidate): boolean
		return Specs.IsValidQueryOptions(candidate.QueryOptions)
	end
)

local HasValidSelectionOptions = Specification.new(
	_ErrorName(Enums.ErrorKey.InvalidSelectionOptions),
	Enums.ErrorMessage[Enums.ErrorKey.InvalidSelectionOptions],
	function(candidate): boolean
		return Specs.IsValidSelectionOptions(candidate.SelectionOptions)
	end
)

local HasValidProjectionPlane = Specification.new(
	_ErrorName(Enums.ErrorKey.InvalidProjectionPlane),
	Enums.ErrorMessage[Enums.ErrorKey.InvalidProjectionPlane],
	function(candidate): boolean
		return Specs.IsValidProjectionPlane(candidate.ProjectionPlane)
	end
)

local HasValidBaseExclude = Specification.new(
	_ErrorName(Enums.ErrorKey.InvalidBaseExclude),
	Enums.ErrorMessage[Enums.ErrorKey.InvalidBaseExclude],
	function(candidate): boolean
		return Specs.IsValidBaseExclude(candidate.BaseExclude)
	end
)

local HasValidMetadata = Specification.new(
	_ErrorName(Enums.ErrorKey.InvalidMetadata),
	Enums.ErrorMessage[Enums.ErrorKey.InvalidMetadata],
	function(candidate): boolean
		return Specs.IsValidMetadata(candidate.Metadata)
	end
)

local HasValidMirrorSelection = Specification.new(
	_ErrorName(Enums.ErrorKey.InvalidSelectionMirror),
	Enums.ErrorMessage[Enums.ErrorKey.InvalidSelectionMirror],
	function(candidate): boolean
		return Specs.IsValidMirrorSelection(candidate.MirrorSelection)
	end
)

local HasValidMirrorHover = Specification.new(
	_ErrorName(Enums.ErrorKey.InvalidHoverMirror),
	Enums.ErrorMessage[Enums.ErrorKey.InvalidHoverMirror],
	function(candidate): boolean
		return Specs.IsValidMirrorHover(candidate.MirrorHover)
	end
)

local HasValidMirrorPreviewSelection = Specification.new(
	_ErrorName(Enums.ErrorKey.InvalidPreviewSelectionMirror),
	Enums.ErrorMessage[Enums.ErrorKey.InvalidPreviewSelectionMirror],
	function(candidate): boolean
		return Specs.IsValidMirrorPreviewSelection(candidate.MirrorPreviewSelection)
	end
)

local HasValidPreviewSelectionChannel = Specification.new(
	_ErrorName(Enums.ErrorKey.InvalidPreviewSelectionChannel),
	Enums.ErrorMessage[Enums.ErrorKey.InvalidPreviewSelectionChannel],
	function(candidate): boolean
		return Specs.IsValidPreviewSelectionChannel(candidate.PreviewSelectionChannel)
	end
)

local HasValidHighlightOptions = Specification.new(
	_ErrorName(Enums.ErrorKey.InvalidSelectionHighlight),
	Enums.ErrorMessage[Enums.ErrorKey.InvalidSelectionHighlight],
	function(candidate): boolean
		return Specs.IsValidHighlightOptions(candidate.Highlight)
	end
)

local HasValidHoverHighlightOptions = Specification.new(
	_ErrorName(Enums.ErrorKey.InvalidHoverHighlight),
	Enums.ErrorMessage[Enums.ErrorKey.InvalidHoverHighlight],
	function(candidate): boolean
		return Specs.IsValidHighlightOptions(if candidate.HoverHighlight ~= nil then candidate.HoverHighlight else candidate.Highlight)
	end
)

local HasValidRadiusOptions = Specification.new(
	_ErrorName(Enums.ErrorKey.InvalidSelectionRadius),
	Enums.ErrorMessage[Enums.ErrorKey.InvalidSelectionRadius],
	function(candidate): boolean
		return Specs.IsValidRadiusOptions(candidate.Radius)
	end
)

local HasValidHoverRadiusOptions = Specification.new(
	_ErrorName(Enums.ErrorKey.InvalidHoverRadius),
	Enums.ErrorMessage[Enums.ErrorKey.InvalidHoverRadius],
	function(candidate): boolean
		return Specs.IsValidRadiusOptions(if candidate.HoverRadius ~= nil then candidate.HoverRadius else candidate.Radius)
	end
)

local HasValidMarqueeQueryOptions = Specification.new(
	_ErrorName(Enums.ErrorKey.InvalidMarqueeQueryOptions),
	Enums.ErrorMessage[Enums.ErrorKey.InvalidMarqueeQueryOptions],
	function(candidate): boolean
		return Specs.IsValidQueryOptions(candidate.MarqueeQueryOptions)
	end
)

local HasValidMarqueeSelectionOptions = Specification.new(
	_ErrorName(Enums.ErrorKey.InvalidMarqueeSelectionOptions),
	Enums.ErrorMessage[Enums.ErrorKey.InvalidMarqueeSelectionOptions],
	function(candidate): boolean
		return Specs.IsValidSelectionOptions(candidate.MarqueeSelectionOptions)
	end
)

local HasValidMarqueeMetadata = Specification.new(
	_ErrorName(Enums.ErrorKey.InvalidMarqueeMetadata),
	Enums.ErrorMessage[Enums.ErrorKey.InvalidMarqueeMetadata],
	function(candidate): boolean
		return Specs.IsValidMetadata(candidate.MarqueeMetadata)
	end
)

local HasClientRuntime = Specification.new(
	_ErrorName(Enums.ErrorKey.UnsupportedRuntime),
	Enums.ErrorMessage[Enums.ErrorKey.UnsupportedRuntime],
	function(candidate): boolean
		return Specs.IsClientRuntime(candidate.IsClient)
	end
)

local HasCamera = Specification.new(
	_ErrorName(Enums.ErrorKey.MissingCamera),
	Enums.ErrorMessage[Enums.ErrorKey.MissingCamera],
	function(candidate): boolean
		return Specs.HasCamera(candidate.Camera)
	end
)

local HasAliveService = Specification.new(
	_ErrorName(Enums.ErrorKey.MouseServiceDestroyed),
	Enums.ErrorMessage[Enums.ErrorKey.MouseServiceDestroyed],
	function(candidate): boolean
		return Specs.IsServiceAlive(candidate.IsDestroyed)
	end
)

local CanBeginDrag = Specification.new(
	_ErrorName(Enums.ErrorKey.DuplicateDragSession),
	Enums.ErrorMessage[Enums.ErrorKey.DuplicateDragSession],
	function(candidate): boolean
		return Specs.CanBeginDrag(candidate.HasSession)
	end
)

local CanOperateOnDrag = Specification.new(
	_ErrorName(Enums.ErrorKey.MissingDragSession),
	Enums.ErrorMessage[Enums.ErrorKey.MissingDragSession],
	function(candidate): boolean
		return Specs.CanOperateOnDrag(candidate.HasSession)
	end
)

local CanBeginHover = Specification.new(
	_ErrorName(Enums.ErrorKey.DuplicateHoverSession),
	Enums.ErrorMessage[Enums.ErrorKey.DuplicateHoverSession],
	function(candidate): boolean
		return Specs.CanBeginHover(candidate.HasSession)
	end
)

local CanOperateOnHover = Specification.new(
	_ErrorName(Enums.ErrorKey.MissingHoverSession),
	Enums.ErrorMessage[Enums.ErrorKey.MissingHoverSession],
	function(candidate): boolean
		return Specs.CanOperateOnHover(candidate.HasSession)
	end
)

Specs.HasValidConfigSpec = HasValidConfig
Specs.HasValidRequestSpec = HasValidRequest
Specs.HasValidChannelNameSpec = HasValidChannelName
Specs.HasValidScreenPointSpec = HasValidScreenPoint
Specs.HasValidCameraProviderSpec = HasValidCameraProvider
Specs.HasValidRayLengthSpec = HasValidRayLength
Specs.HasValidResolveTargetSpec = HasValidResolveTarget
Specs.HasValidDragModeSpec = HasValidDragMode
Specs.HasValidQueryOptionsSpec = HasValidQueryOptions
Specs.HasValidSelectionOptionsSpec = HasValidSelectionOptions
Specs.HasValidProjectionPlaneSpec = HasValidProjectionPlane
Specs.HasValidBaseExcludeSpec = HasValidBaseExclude
Specs.HasValidMetadataSpec = HasValidMetadata
Specs.HasValidMirrorSelectionSpec = HasValidMirrorSelection
Specs.HasValidMirrorHoverSpec = HasValidMirrorHover
Specs.HasValidMirrorPreviewSelectionSpec = HasValidMirrorPreviewSelection
Specs.HasValidPreviewSelectionChannelSpec = HasValidPreviewSelectionChannel
Specs.HasValidHighlightOptionsSpec = HasValidHighlightOptions
Specs.HasValidRadiusOptionsSpec = HasValidRadiusOptions
Specs.HasValidHoverHighlightOptionsSpec = HasValidHoverHighlightOptions
Specs.HasValidHoverRadiusOptionsSpec = HasValidHoverRadiusOptions
Specs.HasValidMarqueeQueryOptionsSpec = HasValidMarqueeQueryOptions
Specs.HasValidMarqueeSelectionOptionsSpec = HasValidMarqueeSelectionOptions
Specs.HasValidMarqueeMetadataSpec = HasValidMarqueeMetadata
Specs.HasClientRuntimeSpec = HasClientRuntime
Specs.HasCameraSpec = HasCamera
Specs.HasAliveServiceSpec = HasAliveService
Specs.CanBeginDragSpec = CanBeginDrag
Specs.CanOperateOnDragSpec = CanOperateOnDrag
Specs.CanBeginHoverSpec = CanBeginHover
Specs.CanOperateOnHoverSpec = CanOperateOnHover
Specs.HasValidManagerConfigSpec = Specification.All({
	HasValidConfig,
	HasValidCameraProvider,
	HasValidRayLength,
	HasValidResolveTarget,
	HasValidDragMode,
	HasValidQueryOptions,
	HasValidSelectionOptions,
	HasValidProjectionPlane,
	HasValidBaseExclude,
	HasValidMirrorSelection,
	HasValidHighlightOptions,
	HasValidRadiusOptions,
	HasValidMirrorHover,
	HasValidHoverHighlightOptions,
	HasValidHoverRadiusOptions,
	HasValidMirrorPreviewSelection,
	HasValidPreviewSelectionChannel,
	HasValidMarqueeQueryOptions,
	HasValidMarqueeSelectionOptions,
	HasValidMarqueeMetadata,
})
Specs.HasValidRequestShapeSpec = Specification.All({
	HasValidRequest,
	HasValidScreenPoint,
	HasValidCameraProvider,
	HasValidRayLength,
	HasValidResolveTarget,
	HasValidDragMode,
	HasValidQueryOptions,
	HasValidSelectionOptions,
	HasValidProjectionPlane,
	HasValidBaseExclude,
})
Specs.HasValidSelectionRequestSpec = Specification.All({
	HasValidRequest,
	HasValidScreenPoint,
	HasValidCameraProvider,
	HasValidRayLength,
	HasValidResolveTarget,
	HasValidQueryOptions,
	HasValidSelectionOptions,
	HasValidProjectionPlane,
	HasValidBaseExclude,
	HasValidMetadata,
	HasValidMirrorSelection,
	HasValidHighlightOptions,
	HasValidRadiusOptions,
})
Specs.HasValidHoverRequestSpec = Specification.All({
	HasValidRequest,
	HasValidScreenPoint,
	HasValidCameraProvider,
	HasValidRayLength,
	HasValidResolveTarget,
	HasValidQueryOptions,
	HasValidSelectionOptions,
	HasValidProjectionPlane,
	HasValidBaseExclude,
	HasValidMetadata,
	HasValidMirrorHover,
	HasValidHoverHighlightOptions,
	HasValidHoverRadiusOptions,
})
Specs.HasValidDragRequestSpec = Specification.All({
	HasValidRequest,
	HasValidScreenPoint,
	HasValidCameraProvider,
	HasValidRayLength,
	HasValidResolveTarget,
	HasValidQueryOptions,
	HasValidSelectionOptions,
	HasValidProjectionPlane,
	HasValidBaseExclude,
	HasValidMetadata,
	HasValidMirrorPreviewSelection,
	HasValidPreviewSelectionChannel,
	HasValidMarqueeQueryOptions,
	HasValidMarqueeSelectionOptions,
	HasValidMarqueeMetadata,
})

return table.freeze(Specs)
