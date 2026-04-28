--!strict

--[=[
    @class SpatialQueryTypes
    Shared type aliases for the `SpatialQuery` package surface.
    @server
    @client
]=]

-- ── Types ─────────────────────────────────────────────────────────────────────

--[=[
    @interface TQueryOptions
    @within SpatialQueryTypes
    Shared filter and collision configuration used by raycast and overlap helpers.
]=]
export type TQueryOptions = {
	FilterType: Enum.RaycastFilterType?,
	FilterDescendantsInstances: { Instance }?,
	CollisionGroup: string?,
	IgnoreWater: boolean?,
	RespectCanCollide: boolean?,
	MaxParts: number?,
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
