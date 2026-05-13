--!strict

local SpatialQuery = require(script.Parent.Parent.Parent.SpatialQuery)
local Enums = require(script.Parent.Enums)

export type TResolvedSelectionTarget = {
	Root: Instance,
	Adornee: Instance,
	Model: Model?,
	WorldPosition: Vector3,
	BoundsCFrame: CFrame?,
	BoundsSize: Vector3?,
	Hit: RaycastResult?,
}

export type TSelectionResolverOptions = {
	RayLength: number?,
	QueryOptions: SpatialQuery.TQueryOptions?,
	AdorneeSelector: string?,
	WorldPositionSelector: string?,
	ResolveRoot: ((hitInstance: Instance, hit: RaycastResult?) -> Instance?)?,
	ResolveAdornee: ((root: Instance, hit: RaycastResult?) -> Instance?)?,
	ResolveWorldPosition: ((root: Instance, hit: RaycastResult?) -> Vector3?)?,
}

export type THighlightConfig = {
	Enabled: boolean?,
	FillColor: Color3?,
	OutlineColor: Color3?,
	FillTransparency: number?,
	OutlineTransparency: number?,
	DepthMode: Enum.HighlightDepthMode?,
	Parent: Instance?,
	Adornee: Instance?,
	BuildVisual: ((target: TResolvedSelectionTarget, config: THighlightConfig, parent: Instance) -> any)?,
}

export type TRadiusConfig = {
	Enabled: boolean?,
	Radius: number?,
	Height: number?,
	Color: Color3?,
	Transparency: number?,
	ClampToGround: boolean?,
	Offset: Vector3?,
	Parent: Instance?,
	QueryOptions: SpatialQuery.TQueryOptions?,
	BuildVisual: ((target: TResolvedSelectionTarget, config: TRadiusConfig, parent: Instance) -> any)?,
}

export type TSelectionTargetLike = Instance | TResolvedSelectionTarget

export type TSelectionRequest = {
	Target: TSelectionTargetLike?,
	ResolverOptions: TSelectionResolverOptions?,
	Highlight: THighlightConfig?,
	Radius: TRadiusConfig?,
	Metadata: { [string]: any }?,
}

export type TSelectionSetRequest = {
	Targets: { TSelectionTargetLike }?,
	ResolverOptions: TSelectionResolverOptions?,
	Highlight: THighlightConfig?,
	Radius: TRadiusConfig?,
	Metadata: { [string]: any }?,
}

export type TSelectionManagerConfig = {
	Parent: Instance?,
	Name: string?,
	DefaultResolverOptions: TSelectionResolverOptions?,
	DefaultHighlight: THighlightConfig?,
	DefaultRadius: TRadiusConfig?,
}

export type TResolvedSelectionRequest = {
	Target: TSelectionTargetLike?,
	ResolverOptions: TSelectionResolverOptions?,
	Highlight: THighlightConfig?,
	Radius: TRadiusConfig?,
	Metadata: { [string]: any }?,
}

export type TResolvedSelectionSetRequest = {
	Targets: { TSelectionTargetLike },
	ResolverOptions: TSelectionResolverOptions?,
	Highlight: THighlightConfig?,
	Radius: TRadiusConfig?,
	Metadata: { [string]: any }?,
}

export type TResolvedSelectionManagerConfig = {
	Parent: Instance?,
	Name: string,
	DefaultResolverOptions: TSelectionResolverOptions?,
	DefaultHighlight: THighlightConfig?,
	DefaultRadius: TRadiusConfig?,
}

export type TSelectionHandleState = typeof(Enums.HandleState.Active)
export type TSelectionMode = typeof(Enums.SelectionMode.Single)
export type TInvalidationReason = typeof(Enums.InvalidationReason.TargetDestroyed)

export type TSelectionEntry = {
	Key: Instance,
	Target: TResolvedSelectionTarget,
}

export type TSelectionSnapshot = {
	Channel: string,
	Mode: TSelectionMode,
	Entries: { TSelectionEntry },
	PrimaryEntry: TSelectionEntry?,
	Metadata: { [string]: any }?,
}

export type TSelectionConnection = {
	Disconnect: (self: TSelectionConnection) -> (),
}

export type TSelectionHandleStateChangedSignal = {
	Connect: (
		self: TSelectionHandleStateChangedSignal,
		callback: (newState: TSelectionHandleState, previousState: TSelectionHandleState) -> ()
	) -> TSelectionConnection,
	Once: (
		self: TSelectionHandleStateChangedSignal,
		callback: (newState: TSelectionHandleState, previousState: TSelectionHandleState) -> ()
	) -> TSelectionConnection,
	Wait: (self: TSelectionHandleStateChangedSignal) -> (TSelectionHandleState, TSelectionHandleState),
}

export type TSelectionChangedSignal = {
	Connect: (
		self: TSelectionChangedSignal,
		callback: (channelName: string, snapshot: TSelectionSnapshot, previousSnapshot: TSelectionSnapshot?) -> ()
	) -> TSelectionConnection,
	Once: (
		self: TSelectionChangedSignal,
		callback: (channelName: string, snapshot: TSelectionSnapshot, previousSnapshot: TSelectionSnapshot?) -> ()
	) -> TSelectionConnection,
	Fire: (
		self: TSelectionChangedSignal,
		channelName: string,
		snapshot: TSelectionSnapshot,
		previousSnapshot: TSelectionSnapshot?
	) -> (),
	Wait: (self: TSelectionChangedSignal) -> (string, TSelectionSnapshot, TSelectionSnapshot?),
	DisconnectAll: (self: TSelectionChangedSignal) -> (),
}

export type TSelectionClearedSignal = {
	Connect: (
		self: TSelectionClearedSignal,
		callback: (channelName: string, previousSnapshot: TSelectionSnapshot, reason: TInvalidationReason) -> ()
	) -> TSelectionConnection,
	Once: (
		self: TSelectionClearedSignal,
		callback: (channelName: string, previousSnapshot: TSelectionSnapshot, reason: TInvalidationReason) -> ()
	) -> TSelectionConnection,
	Fire: (
		self: TSelectionClearedSignal,
		channelName: string,
		previousSnapshot: TSelectionSnapshot,
		reason: TInvalidationReason
	) -> (),
	Wait: (self: TSelectionClearedSignal) -> (string, TSelectionSnapshot, TInvalidationReason),
	DisconnectAll: (self: TSelectionClearedSignal) -> (),
}

export type TSelectionInvalidatedSignal = TSelectionClearedSignal

export type TSelectionHandle = {
	Channel: string,
	Target: TResolvedSelectionTarget?,
	Metadata: { [string]: any }?,
	StateChanged: TSelectionHandleStateChangedSignal,

	GetSnapshot: (self: TSelectionHandle) -> TSelectionSnapshot,
	GetState: (self: TSelectionHandle) -> TSelectionHandleState,
	IsActive: (self: TSelectionHandle) -> boolean,
	Clear: (self: TSelectionHandle) -> (),
	Destroy: (self: TSelectionHandle) -> (),
}

export type TSelectionManager = {
	SelectionChanged: TSelectionChangedSignal,
	SelectionCleared: TSelectionClearedSignal,
	SelectionInvalidated: TSelectionInvalidatedSignal,

	SetSelection: (self: TSelectionManager, channelName: string, request: TSelectionRequest) -> TSelectionHandle?,
	SetSelectionSet: (self: TSelectionManager, channelName: string, request: TSelectionSetRequest) -> TSelectionHandle?,
	ResolveAndSetFromScreenPoint: (
		self: TSelectionManager,
		channelName: string,
		camera: Camera,
		screenPoint: Vector2,
		request: TSelectionRequest?
	) -> TSelectionHandle?,
	GetHandle: (self: TSelectionManager, channelName: string) -> TSelectionHandle?,
	GetSnapshot: (self: TSelectionManager, channelName: string) -> TSelectionSnapshot?,
	GetPrimaryTarget: (self: TSelectionManager, channelName: string) -> TResolvedSelectionTarget?,
	HasSelection: (self: TSelectionManager, channelName: string) -> boolean,
	GetSelectionCount: (self: TSelectionManager, channelName: string) -> number,
	Clear: (self: TSelectionManager, channelName: string) -> (),
	ClearAll: (self: TSelectionManager) -> (),
	Destroy: (self: TSelectionManager) -> (),

	Select: (self: TSelectionManager, channelName: string, request: TSelectionRequest) -> TSelectionHandle?,
	SelectFromScreenPoint: (
		self: TSelectionManager,
		channelName: string,
		camera: Camera,
		screenPoint: Vector2,
		request: TSelectionRequest?
	) -> TSelectionHandle?,
	GetSelection: (self: TSelectionManager, channelName: string) -> TSelectionHandle?,
}

local Types = {}

return Types
