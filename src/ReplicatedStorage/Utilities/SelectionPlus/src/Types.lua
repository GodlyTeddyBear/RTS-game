--!strict

local SpatialQuery = require(script.Parent.Parent.Parent.SpatialQuery)

--[=[
    @class SelectionPlusTypes
    Shared type aliases for the `SelectionPlus` package surface.
    @client
]=]

--[=[
    @interface TResolvedSelectionTarget
    @within SelectionPlusTypes
    Normalized target data consumed by the built-in visual helpers.
    .Root Instance -- Canonical selection root.
    .Adornee Instance -- Highlight adornee resolved for the target.
    .Model Model? -- Model root when the target resolves to a model.
    .WorldPosition Vector3 -- World-space anchor used by range and other visuals.
    .BoundsCFrame CFrame? -- Bounds transform for the resolved target.
    .BoundsSize Vector3? -- Bounds size for the resolved target.
    .Hit RaycastResult? -- Raycast hit used to resolve the target, if any.
]=]
export type TResolvedSelectionTarget = {
	Root: Instance,
	Adornee: Instance,
	Model: Model?,
	WorldPosition: Vector3,
	BoundsCFrame: CFrame?,
	BoundsSize: Vector3?,
	Hit: RaycastResult?,
}

--[=[
    @interface TSelectionResolverOptions
    @within SelectionPlusTypes
    Technical options used while resolving selection targets.
    .RayLength number? -- Cursor ray length used by screen-point selection.
    .QueryOptions TQueryOptions? -- Spatial query options applied to the cursor raycast.
    .AdorneeSelector string? -- Descendant selector used to override the default adornee.
    .WorldPositionSelector string? -- Descendant selector used to override the default world anchor.
    .ResolveRoot function? -- Custom root resolver that receives the hit instance and hit result.
    .ResolveAdornee function? -- Custom adornee resolver that receives the resolved root and hit result.
    .ResolveWorldPosition function? -- Custom anchor resolver that receives the resolved root and hit result.
]=]
export type TSelectionResolverOptions = {
	RayLength: number?,
	QueryOptions: SpatialQuery.TQueryOptions?,
	AdorneeSelector: string?,
	WorldPositionSelector: string?,
	ResolveRoot: ((hitInstance: Instance, hit: RaycastResult?) -> Instance?)?,
	ResolveAdornee: ((root: Instance, hit: RaycastResult?) -> Instance?)?,
	ResolveWorldPosition: ((root: Instance, hit: RaycastResult?) -> Vector3?)?,
}

--[=[
    @interface THighlightConfig
    @within SelectionPlusTypes
    Built-in highlight configuration for one selection request.
    .Enabled boolean? -- Whether the highlight should be created.
    .FillColor Color3? -- Highlight fill color.
    .OutlineColor Color3? -- Highlight outline color.
    .FillTransparency number? -- Highlight fill transparency.
    .OutlineTransparency number? -- Highlight outline transparency.
    .DepthMode Enum.HighlightDepthMode? -- Highlight depth mode.
    .Parent Instance? -- Override parent for the created highlight.
    .Adornee Instance? -- Override adornee for the created highlight.
    .BuildVisual function? -- Optional custom builder that replaces the built-in highlight instance.
]=]
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

--[=[
    @interface TRadiusConfig
    @within SelectionPlusTypes
    Built-in radius indicator configuration for one selection request.
    .Enabled boolean? -- Whether the radius indicator should be created.
    .Radius number -- Radius in studs.
    .Height number? -- Disk thickness in studs.
    .Color Color3? -- Radius visual color.
    .Transparency number? -- Radius visual transparency.
    .ClampToGround boolean? -- Whether the disk should try to rest on the ground below the target.
    .Offset Vector3? -- World-space offset applied before ground clamping.
    .Parent Instance? -- Override parent for the created visual.
    .QueryOptions TQueryOptions? -- Query options used by ground-clamp raycasts.
    .BuildVisual function? -- Optional custom builder that replaces the built-in radius instance.
]=]
export type TRadiusConfig = {
	Enabled: boolean?,
	Radius: number,
	Height: number?,
	Color: Color3?,
	Transparency: number?,
	ClampToGround: boolean?,
	Offset: Vector3?,
	Parent: Instance?,
	QueryOptions: SpatialQuery.TQueryOptions?,
	BuildVisual: ((target: TResolvedSelectionTarget, config: TRadiusConfig, parent: Instance) -> any)?,
}

--[=[
    @interface TSelectionRequest
    @within SelectionPlusTypes
    Selection request payload consumed by the manager APIs.
    .Target Instance | TResolvedSelectionTarget? -- Direct target to select. Screen-point APIs may omit this.
    .ResolverOptions TSelectionResolverOptions? -- Resolver options for target normalization.
    .Highlight THighlightConfig? -- Highlight visual configuration.
    .Radius TRadiusConfig? -- Radius indicator configuration.
    .Metadata table? -- Frozen metadata copied onto the resulting handle.
]=]
export type TSelectionRequest = {
	Target: (Instance | TResolvedSelectionTarget)?,
	ResolverOptions: TSelectionResolverOptions?,
	Highlight: THighlightConfig?,
	Radius: TRadiusConfig?,
	Metadata: { [string]: any }?,
}

--[=[
    @interface TSelectionManagerConfig
    @within SelectionPlusTypes
    Configuration applied when a selection manager is created.
    .Parent Instance? -- Parent instance for the runtime visual folder.
    .Name string? -- Name used for the runtime visual folder.
    .DefaultHighlight THighlightConfig? -- Highlight defaults merged into each request.
    .DefaultRadius TRadiusConfig? -- Radius defaults merged into each request.
]=]
export type TSelectionManagerConfig = {
	Parent: Instance?,
	Name: string?,
	DefaultHighlight: THighlightConfig?,
	DefaultRadius: TRadiusConfig?,
}

export type TSelectionState = "Idle" | "Active" | "Cleared" | "Destroyed"

--[=[
    @interface TSelectionHandle
    @within SelectionPlusTypes
    Public handle returned for one active channel selection.
    .Channel string -- Owning channel name.
    .Target TResolvedSelectionTarget -- Resolved target bound to the handle.
    .Metadata table? -- Frozen metadata copied from the selection request.
    .StateMachine any -- Internal `StateMachine` instance that tracks lifecycle state.
]=]
export type TSelectionHandle = {
	Channel: string,
	Target: TResolvedSelectionTarget,
	Metadata: { [string]: any }?,
	StateMachine: any,
	Destroy: (self: TSelectionHandle) -> (),
}

--[=[
    @interface TSelectionManager
    @within SelectionPlusTypes
    Stateful manager that owns one active selection handle per channel.
]=]
export type TSelectionManager = {
	Select: (self: TSelectionManager, channelName: string, request: TSelectionRequest) -> TSelectionHandle?,
	SelectFromScreenPoint: (
		self: TSelectionManager,
		channelName: string,
		camera: Camera,
		screenPoint: Vector2,
		request: TSelectionRequest?
	) -> TSelectionHandle?,
	GetSelection: (self: TSelectionManager, channelName: string) -> TSelectionHandle?,
	Clear: (self: TSelectionManager, channelName: string) -> (),
	ClearAll: (self: TSelectionManager) -> (),
	Destroy: (self: TSelectionManager) -> (),
}

local Types = {}

return Types
