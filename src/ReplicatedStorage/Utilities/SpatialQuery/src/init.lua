--!strict

local Options = require(script.Options)
local Queries = require(script.Queries)
local Selection = require(script.Selection)
local Presets = require(script.Presets)
local Types = require(script.Types)

-- ── Types ─────────────────────────────────────────────────────────────────────

export type TQueryOptions = Types.TQueryOptions
export type TScoredCandidate<T> = Types.TScoredCandidate<T>

--[=[
    @class SpatialQueryPackage
    Structured package surface for `SpatialQuery` helpers and reusable presets.
    @server
    @client
]=]
--[=[
    @prop Presets table
    @within SpatialQueryPackage
    Frozen preset table for common include/exclude query configurations.
]=]
local SpatialQuery = {
	Presets = Presets,
}

-- ── Public ────────────────────────────────────────────────────────────────────

SpatialQuery.CreateRaycastOptions = Options.Create
SpatialQuery.CreateOverlapOptions = Options.Create
SpatialQuery.MergeOptions = Options.Merge
SpatialQuery.WithExcludedInstances = Options.WithExcludedInstances
SpatialQuery.WithIncludedInstances = Options.WithIncludedInstances
SpatialQuery.WithCollisionGroup = Options.WithCollisionGroup
SpatialQuery.BuildRaycastParams = Options.BuildRaycastParams
SpatialQuery.BuildOverlapParams = Options.BuildOverlapParams

SpatialQuery.Raycast = Queries.Raycast
SpatialQuery.RaycastTo = Queries.RaycastTo
SpatialQuery.OverlapBox = Queries.OverlapBox
SpatialQuery.OverlapRadius = Queries.OverlapRadius
SpatialQuery.OverlapPart = Queries.OverlapPart
SpatialQuery.ContainsPointInBox = Queries.ContainsPointInBox
SpatialQuery.ContainsPointInRadius = Queries.ContainsPointInRadius
SpatialQuery.DistanceSquared = Queries.DistanceSquared
SpatialQuery.IsWithinRange = Queries.IsWithinRange
SpatialQuery.IsWithinRaycastRange = Queries.IsWithinRaycastRange
SpatialQuery.HasLineOfSight = Queries.HasLineOfSight
SpatialQuery.IsTargetVisibleInRange = Queries.IsTargetVisibleInRange

SpatialQuery.FindNearestPart = Selection.FindNearestPart
SpatialQuery.FindNearestPosition = Selection.FindNearestPosition
SpatialQuery.FindNearestModel = Selection.FindNearestModel
SpatialQuery.FindNearestAttachment = Selection.FindNearestAttachment
SpatialQuery.FindAllInRange = Selection.FindAllInRange
SpatialQuery.FindAllPartsInRange = Selection.FindAllPartsInRange
SpatialQuery.FindClosestVisiblePart = Selection.FindClosestVisiblePart
SpatialQuery.FindClosestVisibleModel = Selection.FindClosestVisibleModel
SpatialQuery.SortPartsByDistance = Selection.SortPartsByDistance
SpatialQuery.SortPositionsByDistance = Selection.SortPositionsByDistance
SpatialQuery.FindBestCandidate = Selection.FindBestCandidate

return table.freeze(SpatialQuery)
