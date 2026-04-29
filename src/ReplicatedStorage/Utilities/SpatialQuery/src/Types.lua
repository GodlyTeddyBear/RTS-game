--!strict

--[=[
    @class SpatialQueryTypes
    Shared type aliases for the `SpatialQuery` package surface.
    @server
    @client
]=]

-- ── Types ─────────────────────────────────────────────────────────────────────

--[=[
    @interface TVisualizationOptions
    @within SpatialQueryTypes
    Debug-only visualization configuration for ray-based queries.
    `.Enabled` controls whether a `VectorViz` beam is emitted for the cast.
    `.Color`, `.Width`, and `.Scale` map to the underlying `VectorViz` settings.
    `.Duration` controls auto-cleanup lifetime in seconds.
    `.Name` lets callers reuse a stable visual key across repeated casts.
]=]
export type TVisualizationOptions = {
	Enabled: boolean?,
	Color: Color3?,
	Width: number?,
	Scale: number?,
	Duration: number?,
	Name: string?,
}

--[=[
    @interface TQueryOptions
    @within SpatialQueryTypes
    Shared filter and collision configuration used by raycast and overlap helpers.
    `Visualization` is only consumed by ray-based helpers.
]=]
export type TQueryOptions = {
	FilterType: Enum.RaycastFilterType?,
	FilterDescendantsInstances: { Instance }?,
	CollisionGroup: string?,
	IgnoreWater: boolean?,
	RespectCanCollide: boolean?,
	MaxParts: number?,
	Visualization: TVisualizationOptions?,
}

--[=[
    @interface TScoredCandidate<T>
    @within SpatialQueryTypes
    Generic scored candidate payload used by best-candidate selection helpers.
]=]
export type TScoredCandidate<T> = {
	Candidate: T,
	DistanceSquared: number,
	Score: number,
}

local Types = {}

return Types
