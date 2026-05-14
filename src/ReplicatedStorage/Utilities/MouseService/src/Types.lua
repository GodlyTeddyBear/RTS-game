--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Result = require(ReplicatedStorage.Utilities.Result)
local SelectionPlus = require(ReplicatedStorage.Utilities.SelectionPlus)
local SpatialQuery = require(ReplicatedStorage.Utilities.SpatialQuery)

local Enums = require(script.Parent.Enums)

export type TProjectionPlane = {
	Point: Vector3,
	Normal: Vector3,
}

export type TCameraProvider = () -> Camera?

export type TMouseManagerConfig = {
	CameraProvider: TCameraProvider?,
	RayLength: number?,
	ResolveTarget: boolean?,
	QueryOptions: SpatialQuery.TQueryOptions?,
	SelectionOptions: SelectionPlus.TSelectionResolverOptions?,
	ProjectionPlane: TProjectionPlane?,
	BaseExclude: { Instance }?,
	SelectionParent: Instance?,
	MirrorSelections: boolean?,
	DefaultSelectionHighlight: SelectionPlus.THighlightConfig?,
	DefaultSelectionRadius: SelectionPlus.TRadiusConfig?,
	MirrorHovers: boolean?,
	DefaultHoverHighlight: SelectionPlus.THighlightConfig?,
	DefaultHoverRadius: SelectionPlus.TRadiusConfig?,
}

export type TMouseRequest = {
	ScreenPoint: Vector2?,
	CameraProvider: TCameraProvider?,
	RayLength: number?,
	ResolveTarget: boolean?,
	QueryOptions: SpatialQuery.TQueryOptions?,
	SelectionOptions: SelectionPlus.TSelectionResolverOptions?,
	ProjectionPlane: TProjectionPlane?,
	BaseExclude: { Instance }?,
}

export type TResolvedMouseRequest = {
	ScreenPoint: Vector2?,
	CameraProvider: TCameraProvider?,
	RayLength: number,
	ResolveTarget: boolean,
	QueryOptions: SpatialQuery.TQueryOptions?,
	SelectionOptions: SelectionPlus.TSelectionResolverOptions?,
	ProjectionPlane: TProjectionPlane?,
	BaseExclude: { Instance },
}

export type TMouseSnapshot = {
	Source: TMouseSnapshotSource,
	ScreenPoint: Vector2,
	Camera: Camera,
	RayOrigin: Vector3,
	RayDirection: Vector3,
	RayLength: number,
	Hit: RaycastResult?,
	WorldPoint: Vector3?,
	ProjectedWorldPoint: Vector3?,
	ResolvedTarget: SelectionPlus.TResolvedSelectionTarget?,
}

export type TMouseErrorData = {
	ChannelName: string?,
	ScreenPoint: Vector2?,
	RayLength: number?,
	Reason: string?,
	State: string?,
}

export type TMouseSnapshotSource = typeof(Enums.SnapshotSource.CurrentMouse)
export type TMouseSelectionMode = typeof(Enums.SelectionMode.Single)
export type TMouseHoverState = typeof(Enums.HoverState.Active)
export type TMouseDragMode = typeof(Enums.DragMode.World)
export type TMouseDragState = typeof(Enums.DragState.Active)
export type TMouseDragEndReason = typeof(Enums.DragEndReason.Completed)

export type TMouseSelectionRequest = TMouseRequest & {
	Metadata: { [string]: any }?,
	MirrorSelection: boolean?,
	Highlight: SelectionPlus.THighlightConfig?,
	Radius: SelectionPlus.TRadiusConfig?,
}

export type TResolvedMouseSelectionRequest = TResolvedMouseRequest & {
	Metadata: { [string]: any }?,
	MirrorSelection: boolean,
	Highlight: SelectionPlus.THighlightConfig?,
	Radius: SelectionPlus.TRadiusConfig?,
}

export type TMouseSelectionSnapshot = {
	Channel: string,
	Mode: TMouseSelectionMode,
	MouseSnapshot: TMouseSnapshot,
	Target: SelectionPlus.TResolvedSelectionTarget,
	Metadata: { [string]: any }?,
	Mirrored: boolean,
}

export type THoverRequest = TMouseRequest & {
	Metadata: { [string]: any }?,
	MirrorHover: boolean?,
	Highlight: SelectionPlus.THighlightConfig?,
	Radius: SelectionPlus.TRadiusConfig?,
}

export type TResolvedHoverRequest = TResolvedMouseRequest & {
	Metadata: { [string]: any }?,
	MirrorHover: boolean,
	Highlight: SelectionPlus.THighlightConfig?,
	Radius: SelectionPlus.TRadiusConfig?,
}

export type THoverSnapshot = {
	Channel: string,
	State: TMouseHoverState,
	MouseSnapshot: TMouseSnapshot,
	Target: SelectionPlus.TResolvedSelectionTarget,
	Metadata: { [string]: any }?,
	Mirrored: boolean,
}

export type TScreenRect = {
	Min: Vector2,
	Max: Vector2,
	Center: Vector2,
	Size: Vector2,
}

export type TMarqueeTargetEntry = {
	Key: Instance,
	Target: SelectionPlus.TResolvedSelectionTarget,
	ScreenPoint: Vector2,
	BoundsRect: TScreenRect?,
}

export type TMouseDragRequest = TMouseRequest & {
	Metadata: { [string]: any }?,
	DragMode: TMouseDragMode?,
	PreviewSelectionChannel: string?,
	MirrorPreviewSelection: boolean?,
	MarqueeQueryOptions: SpatialQuery.TQueryOptions?,
	MarqueeSelectionOptions: SelectionPlus.TSelectionResolverOptions?,
	MarqueeMetadata: { [string]: any }?,
}

export type TResolvedMouseDragRequest = TResolvedMouseRequest & {
	Metadata: { [string]: any }?,
	DragMode: TMouseDragMode,
	PreviewSelectionChannel: string?,
	MirrorPreviewSelection: boolean,
	MarqueeQueryOptions: SpatialQuery.TQueryOptions?,
	MarqueeSelectionOptions: SelectionPlus.TSelectionResolverOptions?,
	MarqueeMetadata: { [string]: any }?,
}

export type TMarqueeRequest = TMouseDragRequest
export type TResolvedMarqueeRequest = TResolvedMouseDragRequest

export type TMouseDragSnapshot = {
	Channel: string,
	Mode: TMouseDragMode,
	State: TMouseDragState,
	EndReason: TMouseDragEndReason?,
	StartSnapshot: TMouseSnapshot,
	CurrentSnapshot: TMouseSnapshot,
	EndSnapshot: TMouseSnapshot?,
	StartWorldPoint: Vector3?,
	CurrentWorldPoint: Vector3?,
	EndWorldPoint: Vector3?,
	StartProjectedWorldPoint: Vector3?,
	CurrentProjectedWorldPoint: Vector3?,
	EndProjectedWorldPoint: Vector3?,
	ScreenDelta: Vector2,
	WorldDelta: Vector3?,
	NormalizedScreenRect: TScreenRect?,
	PreviewTargets: { TMarqueeTargetEntry }?,
	PreviewTargetCount: number?,
	PreviewMirrored: boolean?,
	Metadata: { [string]: any }?,
}

export type TMouseConnection = {
	Disconnect: (self: TMouseConnection) -> (),
}

export type TMouseSelectionChangedSignal = {
	Connect: (
		self: TMouseSelectionChangedSignal,
		callback: (channelName: string, snapshot: TMouseSelectionSnapshot, previousSnapshot: TMouseSelectionSnapshot?) -> ()
	) -> TMouseConnection,
	Once: (
		self: TMouseSelectionChangedSignal,
		callback: (channelName: string, snapshot: TMouseSelectionSnapshot, previousSnapshot: TMouseSelectionSnapshot?) -> ()
	) -> TMouseConnection,
	Fire: (
		self: TMouseSelectionChangedSignal,
		channelName: string,
		snapshot: TMouseSelectionSnapshot,
		previousSnapshot: TMouseSelectionSnapshot?
	) -> (),
	Wait: (self: TMouseSelectionChangedSignal) -> (string, TMouseSelectionSnapshot, TMouseSelectionSnapshot?),
	DisconnectAll: (self: TMouseSelectionChangedSignal) -> (),
}

export type TMouseSelectionClearedSignal = {
	Connect: (
		self: TMouseSelectionClearedSignal,
		callback: (channelName: string, previousSnapshot: TMouseSelectionSnapshot) -> ()
	) -> TMouseConnection,
	Once: (
		self: TMouseSelectionClearedSignal,
		callback: (channelName: string, previousSnapshot: TMouseSelectionSnapshot) -> ()
	) -> TMouseConnection,
	Fire: (self: TMouseSelectionClearedSignal, channelName: string, previousSnapshot: TMouseSelectionSnapshot) -> (),
	Wait: (self: TMouseSelectionClearedSignal) -> (string, TMouseSelectionSnapshot),
	DisconnectAll: (self: TMouseSelectionClearedSignal) -> (),
}

export type THoverChangedSignal = {
	Connect: (
		self: THoverChangedSignal,
		callback: (channelName: string, snapshot: THoverSnapshot, previousSnapshot: THoverSnapshot?) -> ()
	) -> TMouseConnection,
	Once: (
		self: THoverChangedSignal,
		callback: (channelName: string, snapshot: THoverSnapshot, previousSnapshot: THoverSnapshot?) -> ()
	) -> TMouseConnection,
	Fire: (
		self: THoverChangedSignal,
		channelName: string,
		snapshot: THoverSnapshot,
		previousSnapshot: THoverSnapshot?
	) -> (),
	Wait: (self: THoverChangedSignal) -> (string, THoverSnapshot, THoverSnapshot?),
	DisconnectAll: (self: THoverChangedSignal) -> (),
}

export type THoverClearedSignal = {
	Connect: (
		self: THoverClearedSignal,
		callback: (channelName: string, previousSnapshot: THoverSnapshot) -> ()
	) -> TMouseConnection,
	Once: (
		self: THoverClearedSignal,
		callback: (channelName: string, previousSnapshot: THoverSnapshot) -> ()
	) -> TMouseConnection,
	Fire: (self: THoverClearedSignal, channelName: string, previousSnapshot: THoverSnapshot) -> (),
	Wait: (self: THoverClearedSignal) -> (string, THoverSnapshot),
	DisconnectAll: (self: THoverClearedSignal) -> (),
}

export type TMouseDragChangedSignal = {
	Connect: (
		self: TMouseDragChangedSignal,
		callback: (channelName: string, snapshot: TMouseDragSnapshot, previousSnapshot: TMouseDragSnapshot?) -> ()
	) -> TMouseConnection,
	Once: (
		self: TMouseDragChangedSignal,
		callback: (channelName: string, snapshot: TMouseDragSnapshot, previousSnapshot: TMouseDragSnapshot?) -> ()
	) -> TMouseConnection,
	Fire: (
		self: TMouseDragChangedSignal,
		channelName: string,
		snapshot: TMouseDragSnapshot,
		previousSnapshot: TMouseDragSnapshot?
	) -> (),
	Wait: (self: TMouseDragChangedSignal) -> (string, TMouseDragSnapshot, TMouseDragSnapshot?),
	DisconnectAll: (self: TMouseDragChangedSignal) -> (),
}

export type TMouseDragEndedSignal = {
	Connect: (
		self: TMouseDragEndedSignal,
		callback: (channelName: string, snapshot: TMouseDragSnapshot, previousSnapshot: TMouseDragSnapshot?) -> ()
	) -> TMouseConnection,
	Once: (
		self: TMouseDragEndedSignal,
		callback: (channelName: string, snapshot: TMouseDragSnapshot, previousSnapshot: TMouseDragSnapshot?) -> ()
	) -> TMouseConnection,
	Fire: (
		self: TMouseDragEndedSignal,
		channelName: string,
		snapshot: TMouseDragSnapshot,
		previousSnapshot: TMouseDragSnapshot?
	) -> (),
	Wait: (self: TMouseDragEndedSignal) -> (string, TMouseDragSnapshot, TMouseDragSnapshot?),
	DisconnectAll: (self: TMouseDragEndedSignal) -> (),
}

export type TMarqueePreviewChangedSignal = TMouseDragChangedSignal

export type TMouseManager = {
	SelectionChanged: TMouseSelectionChangedSignal,
	SelectionCleared: TMouseSelectionClearedSignal,
	HoverChanged: THoverChangedSignal,
	HoverCleared: THoverClearedSignal,
	MarqueePreviewChanged: TMarqueePreviewChangedSignal,
	DragStarted: TMouseDragChangedSignal,
	DragUpdated: TMouseDragChangedSignal,
	DragEnded: TMouseDragEndedSignal,
	DragCancelled: TMouseDragEndedSignal,

	ResolveSnapshot: (self: TMouseManager, request: TMouseRequest?) -> Result.Result<TMouseSnapshot>,
	ResolveWorldPoint: (self: TMouseManager, request: TMouseRequest?) -> Result.Result<Vector3?>,
	ResolveTarget: (self: TMouseManager, request: TMouseRequest?) -> Result.Result<SelectionPlus.TResolvedSelectionTarget?>,
	SetSelection: (self: TMouseManager, channelName: string, request: TMouseSelectionRequest?) -> Result.Result<TMouseSelectionSnapshot>,
	SetSelectionFromCurrentMouse: (
		self: TMouseManager,
		channelName: string,
		request: TMouseSelectionRequest?
	) -> Result.Result<TMouseSelectionSnapshot>,
	ClearSelection: (self: TMouseManager, channelName: string) -> Result.Result<TMouseSelectionSnapshot?>,
	ClearAllSelections: (self: TMouseManager) -> (),
	GetSelectionSnapshot: (self: TMouseManager, channelName: string) -> TMouseSelectionSnapshot?,
	GetSelectionTarget: (self: TMouseManager, channelName: string) -> SelectionPlus.TResolvedSelectionTarget?,
	HasSelection: (self: TMouseManager, channelName: string) -> boolean,
	BeginHover: (self: TMouseManager, channelName: string, request: THoverRequest?) -> Result.Result<THoverSnapshot>,
	RefreshHover: (self: TMouseManager, channelName: string, request: THoverRequest?) -> Result.Result<THoverSnapshot>,
	EndHover: (self: TMouseManager, channelName: string) -> Result.Result<THoverSnapshot?>,
	GetHoverSnapshot: (self: TMouseManager, channelName: string) -> THoverSnapshot?,
	GetHoverTarget: (self: TMouseManager, channelName: string) -> SelectionPlus.TResolvedSelectionTarget?,
	IsHovering: (self: TMouseManager, channelName: string) -> boolean,
	BeginDrag: (self: TMouseManager, channelName: string, request: TMouseDragRequest?) -> Result.Result<TMouseDragSnapshot>,
	UpdateDrag: (self: TMouseManager, channelName: string, request: TMouseDragRequest?) -> Result.Result<TMouseDragSnapshot>,
	EndDrag: (self: TMouseManager, channelName: string, request: TMouseDragRequest?) -> Result.Result<TMouseDragSnapshot>,
	CancelDrag: (self: TMouseManager, channelName: string) -> Result.Result<TMouseDragSnapshot>,
	BeginMarquee: (self: TMouseManager, channelName: string, request: TMarqueeRequest?) -> Result.Result<TMouseDragSnapshot>,
	UpdateMarquee: (self: TMouseManager, channelName: string, request: TMarqueeRequest?) -> Result.Result<TMouseDragSnapshot>,
	EndMarquee: (self: TMouseManager, channelName: string, request: TMarqueeRequest?) -> Result.Result<TMouseDragSnapshot>,
	CancelMarquee: (self: TMouseManager, channelName: string) -> Result.Result<TMouseDragSnapshot>,
	GetDragSnapshot: (self: TMouseManager, channelName: string) -> TMouseDragSnapshot?,
	IsDragging: (self: TMouseManager, channelName: string) -> boolean,
	GetMarqueeSnapshot: (self: TMouseManager, channelName: string) -> TMouseDragSnapshot?,
	IsMarqueeActive: (self: TMouseManager, channelName: string) -> boolean,
	GetLastSnapshot: (self: TMouseManager) -> TMouseSnapshot?,
	ClearLastSnapshot: (self: TMouseManager) -> (),
	Destroy: (self: TMouseManager) -> (),
}

local Types = {}

return Types
