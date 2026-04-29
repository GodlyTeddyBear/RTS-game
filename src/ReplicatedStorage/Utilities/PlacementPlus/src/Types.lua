--!strict

local SpatialQuery = require(script.Parent.Parent.Parent.SpatialQuery)
local Orient = require(script.Parent.Parent.Parent.Orient)

--[=[
    @class PlacementPlusTypes
    Shared type aliases for the `PlacementPlus` package surface.
    @server
    @client
]=]

-- ── Types ─────────────────────────────────────────────────────────────────────

--[=[
    @interface TPlacementCandidate
    @within PlacementPlusTypes
    Frozen placement candidate payload used by preview and validation helpers.
    .CFrame CFrame -- Final candidate transform.
    .Position Vector3 -- World position used by validation checks.
    .Hit RaycastResult? -- Source raycast hit, if the candidate came from a raycast.
    .SurfaceNormal Vector3? -- Surface normal used by slope and offset logic.
    .SurfaceInstance Instance? -- Surface instance resolved from the hit, if any.
    .SurfaceMaterial Enum.Material? -- Surface material resolved from the hit, if any.
    .Model Model? -- Model used for bounds resolution and ground alignment, if any.
    .BoundsCFrame CFrame? -- Bounds transform used by clearance checks.
    .BoundsSize Vector3? -- Bounds size used by clearance checks.
    .Metadata table? -- Frozen metadata copied from the placement options.
]=]
export type TPlacementCandidate = {
	CFrame: CFrame,
	Position: Vector3,
	Hit: RaycastResult?,
	SurfaceNormal: Vector3?,
	SurfaceInstance: Instance?,
	SurfaceMaterial: Enum.Material?,
	Model: Model?,
	BoundsCFrame: CFrame?,
	BoundsSize: Vector3?,
	Metadata: { [string]: any }?,
}

--[=[
    @interface TPlacementValidationReasonDetail
    @within PlacementPlusTypes
    Structured detail payload for one validation failure.
    .Code string -- Stable validation reason code.
    .MessageKey string? -- Optional UI localization/message lookup key.
    .Data table? -- Optional diagnostic payload for UI or debugging.
]=]
export type TPlacementValidationReasonDetail = {
	Code: string,
	MessageKey: string?,
	Data: { [string]: any }?,
}

--[=[
    @interface TPlacementValidationResult
    @within PlacementPlusTypes
    Structured validation outcome returned after built-in and custom checks run.
    .IsValid boolean -- Whether the candidate passed every validation rule.
    .Reasons { string } -- All failure reasons collected for the candidate.
    .PrimaryReason string? -- First failure reason, or `nil` when the candidate is valid.
    .ReasonDetails { TPlacementValidationReasonDetail } -- Structured details for each failure reason.
]=]
export type TPlacementValidationResult = {
	IsValid: boolean,
	Reasons: { string },
	PrimaryReason: string?,
	ReasonDetails: { TPlacementValidationReasonDetail },
}

--[=[
    @type TPlacementSupportPointMode "Center" | "Corners" | "CenterAndCorners"
    @within PlacementPlusTypes
    Footprint support-point generation mode.
]=]
export type TPlacementSupportPointMode = "Center" | "Corners" | "CenterAndCorners"

--[=[
    @interface TPlacementFootprint
    @within PlacementPlusTypes
    Ground footprint data used to derive clearance size and local support points.
    .Size Vector3 -- Ground footprint size.
    .Padding Vector3? -- Optional padding added to clearance size.
    .SupportPointMode TPlacementSupportPointMode? -- Support-point generation mode.
    .SupportPoints { Vector3 }? -- Explicit local-space support points.
]=]
export type TPlacementFootprint = {
	Size: Vector3,
	Padding: Vector3?,
	SupportPointMode: TPlacementSupportPointMode?,
	SupportPoints: { Vector3 }?,
}

--[=[
    @interface TPlacementResult
    @within PlacementPlusTypes
    Combined candidate and validation payload returned by placement resolution.
    .Candidate TPlacementCandidate? -- Built candidate, or `nil` when input could not produce one.
    .Validation TPlacementValidationResult -- Frozen validation outcome for the resolved candidate.
]=]
export type TPlacementResult = {
	Candidate: TPlacementCandidate?,
	Validation: TPlacementValidationResult,
}

--[=[
    @interface TPlacementOptions
    @within PlacementPlusTypes
    Candidate transform options applied while building a placement candidate.
    .Model Model? -- Model used to derive bounds and support-aware placement.
    .CFrame CFrame? -- Base transform to offset from when building the candidate.
    .Rotation CFrame? -- Explicit rotation source when the base transform is not supplied.
    .PositionGridSize TGridSize? -- Grid size used to snap the candidate position.
    .YawStepDegrees number? -- Yaw step used to snap the final facing direction.
    .YawRadians number? -- Absolute yaw applied when a target face is not supplied.
    .FaceTarget Vector3? -- World position used to orient the candidate toward a target.
    .AlignToGround boolean? -- Whether to lift the model so its bounds rest on the hit height.
    .SurfaceOffset number? -- Offset applied along the hit normal before snapping.
    .BoundsCFrame CFrame? -- Explicit bounds transform used by clearance checks.
    .BoundsSize Vector3? -- Explicit bounds size used by clearance checks.
    .Metadata table? -- Frozen metadata copied onto the candidate for downstream consumers.
]=]
export type TPlacementOptions = {
	Model: Model?,
	CFrame: CFrame?,
	Rotation: CFrame?,
	PositionGridSize: Orient.TGridSize?,
	YawStepDegrees: number?,
	YawRadians: number?,
	FaceTarget: Vector3?,
	AlignToGround: boolean?,
	SurfaceOffset: number?,
	BoundsCFrame: CFrame?,
	BoundsSize: Vector3?,
	Metadata: { [string]: any }?,
}

--[=[
    @interface TPlacementValidationOptions
    @within PlacementPlusTypes
    Technical validation options used by built-in and custom placement checks.
    .BoundsMin Vector3? -- Minimum world-space bounds allowed for the candidate position.
    .BoundsMax Vector3? -- Maximum world-space bounds allowed for the candidate position.
    .AllowedMaterials { [Enum.Material]: boolean }? -- Materials allowed for the supporting surface.
    .AllowedInstances { Instance }? -- Instances or ancestors allowed for the supporting surface.
    .SurfacePredicate ((TPlacementCandidate) -> boolean)? -- Custom surface predicate applied after built-in filters.
    .MaxSlopeDegrees number? -- Maximum allowed slope angle in degrees.
    .RequireClearance boolean? -- Whether the candidate footprint must be free of overlapping parts.
    .ClearanceSize Vector3? -- Clearance box size used instead of the candidate bounds when provided.
    .ClearancePadding Vector3? -- Additional clearance padding added to the resolved box size.
    .ClearanceQueryOptions TQueryOptions? -- Spatial query options used for clearance overlap checks.
    .RequireSupport boolean? -- Whether the candidate must have support under each support point.
    .SupportDistance number? -- Legacy support ray length used when an explicit ray length is not provided.
    .SupportRayLength number? -- Ray length used for downward support checks.
    .SupportPoints { Vector3 }? -- Local-space support points transformed into world space before raycasts.
    .SupportQueryOptions TQueryOptions? -- Spatial query options used for support raycasts.
    .CustomValidators { (TPlacementCandidate, TPlacementValidationOptions) -> string? }? -- Extra validators that append custom failure reasons.
]=]
export type TPlacementValidationOptions = {
	BoundsMin: Vector3?,
	BoundsMax: Vector3?,
	AllowedMaterials: { [Enum.Material]: boolean }?,
	AllowedInstances: { Instance }?,
	SurfacePredicate: ((TPlacementCandidate) -> boolean)?,
	MaxSlopeDegrees: number?,
	RequireClearance: boolean?,
	ClearanceSize: Vector3?,
	ClearancePadding: Vector3?,
	ClearanceQueryOptions: SpatialQuery.TQueryOptions?,
	RequireSupport: boolean?,
	SupportDistance: number?,
	SupportRayLength: number?,
	SupportPoints: { Vector3 }?,
	SupportQueryOptions: SpatialQuery.TQueryOptions?,
	CustomValidators: {
		(TPlacementCandidate, TPlacementValidationOptions) -> (string | TPlacementValidationReasonDetail)?
	}?,
}

--[=[
    @interface TPlacementProfile
    @within PlacementPlusTypes
    Frozen reusable placement profile for repeated candidate and validation resolution.
    .PlacementOptions TPlacementOptions -- Base candidate options.
    .ValidationOptions TPlacementValidationOptions -- Base validation options.
    .Footprint TPlacementFootprint? -- Optional footprint used to derive clearance and support defaults.
    .Metadata table? -- Frozen metadata copied onto merged placement options.
]=]
export type TPlacementProfile = {
	PlacementOptions: TPlacementOptions,
	ValidationOptions: TPlacementValidationOptions,
	Footprint: TPlacementFootprint?,
	Metadata: { [string]: any }?,
}

--[=[
    @interface TPlacementProfileSpec
    @within PlacementPlusTypes
    Input shape accepted by `CreateProfile`.
    .PlacementOptions TPlacementOptions? -- Base candidate options.
    .ValidationOptions TPlacementValidationOptions? -- Base validation options.
    .Footprint TPlacementFootprint? -- Optional footprint defaults.
    .Metadata table? -- Optional reusable metadata.
]=]
export type TPlacementProfileSpec = {
	PlacementOptions: TPlacementOptions?,
	ValidationOptions: TPlacementValidationOptions?,
	Footprint: TPlacementFootprint?,
	Metadata: { [string]: any }?,
}

--[=[
    @interface TPlacementInput
    @within PlacementPlusTypes
    Placement input resolved from raycast, cursor, or direct world position data.
    .Hit RaycastResult? -- Pre-resolved raycast hit, if one is already available.
    .Position Vector3? -- Direct world position used when no hit or camera input exists.
    .Camera Camera? -- Camera used to build a cursor ray when screen input is supplied.
    .ScreenPosition Vector2? -- Screen-space cursor position used with `Camera`.
    .RayLength number? -- Optional ray length used when building a cursor candidate.
    .QueryOptions TQueryOptions? -- Spatial query options used by cursor raycasts.
]=]
export type TPlacementInput = {
	Hit: RaycastResult?,
	Position: Vector3?,
	Camera: Camera?,
	ScreenPosition: Vector2?,
	RayLength: number?,
	QueryOptions: SpatialQuery.TQueryOptions?,
}

local Types = {}

return Types
