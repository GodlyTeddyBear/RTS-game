--!strict

--[=[
    @class SpatialQuery
    Stateless shared helpers for Roblox spatial queries, distance checks, and candidate selection.

    Preserves the legacy require path while re-exporting the structured `src/` package surface.
    @server
    @client
]=]

local SpatialQuery = require(script.src)

--[=[
    @type TQueryOptions
    @within SpatialQuery
    Shared filter and collision configuration used by raycast and overlap helpers.
]=]
export type TQueryOptions = SpatialQuery.TQueryOptions

--[=[
    @type TScoredCandidate<T>
    @within SpatialQuery
    Generic scored candidate payload used by best-candidate selection helpers.
]=]
export type TScoredCandidate<T> = SpatialQuery.TScoredCandidate<T>

return SpatialQuery
