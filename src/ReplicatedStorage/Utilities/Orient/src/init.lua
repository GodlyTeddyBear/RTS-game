--!strict

local Conversion = require(script.Conversion)
local Facing = require(script.Facing)
local Interpolation = require(script.Interpolation)
local Patterns = require(script.Patterns)
local Projection = require(script.Projection)
local Random = require(script.Random)
local Snapping = require(script.Snapping)
local Spatial = require(script.Spatial)
local Translation = require(script.Translation)
local Validation = require(script.Validation)

export type TGridSize = number | Vector3

--[=[
    @class OrientPackage
    Internal package surface for the shared `Orient` transform helpers.

    The table below groups the re-exported helpers by behavior family so the
    public API stays easy to scan without splitting the package into many
    top-level modules.
    @server
    @client
]=]
local Orient = {}

-- Facing / Orientation
Orient.GetRotation = Facing.GetRotation
Orient.BuildFromRotation = Facing.BuildFromRotation
Orient.BuildLookAt = Facing.BuildLookAt
Orient.BuildFlatLookAt = Facing.BuildFlatLookAt
Orient.GetDirection = Facing.GetDirection
Orient.GetFlatDirection = Facing.GetFlatDirection
Orient.SafeUnit = Facing.SafeUnit
Orient.RotateYaw = Facing.RotateYaw
Orient.GetYaw = Facing.GetYaw
Orient.SetYaw = Facing.SetYaw

-- Translation / Offsets
Orient.BuildAtPosition = Translation.BuildAtPosition
Orient.TranslateWorld = Translation.TranslateWorld
Orient.TranslateLocal = Translation.TranslateLocal
Orient.OffsetWorld = Translation.OffsetWorld
Orient.OffsetLocal = Translation.OffsetLocal
Orient.MoveTowards = Translation.MoveTowards
Orient.MoveCFrameTowards = Translation.MoveCFrameTowards
Orient.WithX = Translation.WithX
Orient.WithY = Translation.WithY
Orient.WithZ = Translation.WithZ
Orient.WithPosition = Translation.WithPosition

-- Snapping / Quantization
Orient.SnapScalar = Snapping.SnapScalar
Orient.SnapPosition = Snapping.SnapPosition
Orient.SnapCFramePosition = Snapping.SnapCFramePosition
Orient.SnapYaw = Snapping.SnapYaw
Orient.SnapAngleRadians = Snapping.SnapAngleRadians
Orient.SnapAngleDegrees = Snapping.SnapAngleDegrees
Orient.SnapRotationYaw = Snapping.SnapRotationYaw
Orient.SnapTransform = Snapping.SnapTransform

-- Interpolation / Blending
Orient.LerpPosition = Interpolation.LerpPosition
Orient.LerpCFrame = Interpolation.LerpCFrame
Orient.LerpRotation = Interpolation.LerpRotation
Orient.LerpYaw = Interpolation.LerpYaw
Orient.BlendPosition = Interpolation.BlendPosition
Orient.BlendCFrame = Interpolation.BlendCFrame
Orient.BlendYaw = Interpolation.BlendYaw
Orient.LookAtTowards = Interpolation.LookAtTowards
Orient.FlatLookAtTowards = Interpolation.FlatLookAtTowards

-- Spatial Relationships
Orient.Distance = Spatial.Distance
Orient.DistanceSquared = Spatial.DistanceSquared
Orient.FlatDistance = Spatial.FlatDistance
Orient.FlatDistanceSquared = Spatial.FlatDistanceSquared
Orient.IsWithinRange = Spatial.IsWithinRange
Orient.IsWithinFlatRange = Spatial.IsWithinFlatRange
Orient.ProjectToXZ = Spatial.ProjectToXZ
Orient.ProjectToY = Spatial.ProjectToY
Orient.FlattenToHeight = Spatial.FlattenToHeight
Orient.GetForward = Spatial.GetForward
Orient.GetRight = Spatial.GetRight
Orient.GetUp = Spatial.GetUp
Orient.GetFlatForward = Spatial.GetFlatForward
Orient.GetOffsetBetween = Spatial.GetOffsetBetween
Orient.GetLocalOffset = Spatial.GetLocalOffset
Orient.GetWorldOffset = Spatial.GetWorldOffset
Orient.IsInFront = Spatial.IsInFront
Orient.IsBehind = Spatial.IsBehind
Orient.IsLeftOf = Spatial.IsLeftOf
Orient.IsRightOf = Spatial.IsRightOf
Orient.DotToTarget = Spatial.DotToTarget
Orient.FlatDotToTarget = Spatial.FlatDotToTarget
Orient.AngleToTarget = Spatial.AngleToTarget
Orient.FlatAngleToTarget = Spatial.FlatAngleToTarget

-- Orbit / Arc / Pattern Generation
Orient.GetPointOnCircle = Patterns.GetPointOnCircle
Orient.GetPointOnFlatCircle = Patterns.GetPointOnFlatCircle
Orient.GetPointsOnCircle = Patterns.GetPointsOnCircle
Orient.GetPointsOnArc = Patterns.GetPointsOnArc
Orient.GetPointInFront = Patterns.GetPointInFront
Orient.GetPointBehind = Patterns.GetPointBehind
Orient.GetPointRight = Patterns.GetPointRight
Orient.GetPointLeft = Patterns.GetPointLeft
Orient.GetPointAbove = Patterns.GetPointAbove
Orient.GetPointBelow = Patterns.GetPointBelow
Orient.GetOffsetPoint = Patterns.GetOffsetPoint
Orient.GetRadialOffsets = Patterns.GetRadialOffsets
Orient.GetRingPositions = Patterns.GetRingPositions
Orient.GetFormationLine = Patterns.GetFormationLine
Orient.GetFormationColumn = Patterns.GetFormationColumn
Orient.GetFormationGrid = Patterns.GetFormationGrid
Orient.GetSpiralPositions = Patterns.GetSpiralPositions
Orient.GetOrbitCFrame = Patterns.GetOrbitCFrame

-- Plane / Projection / Clamping
Orient.ProjectPointToPlane = Projection.ProjectPointToPlane
Orient.ProjectVectorToPlane = Projection.ProjectVectorToPlane
Orient.ProjectPointToLine = Projection.ProjectPointToLine
Orient.ClosestPointOnSegment = Projection.ClosestPointOnSegment
Orient.ClosestPointOnRay = Projection.ClosestPointOnRay
Orient.ClampPosition = Projection.ClampPosition
Orient.ClampXZ = Projection.ClampXZ
Orient.ClampY = Projection.ClampY
Orient.ClampMagnitude = Projection.ClampMagnitude
Orient.SetHeight = Projection.SetHeight
Orient.SetCFrameHeight = Projection.SetCFrameHeight
Orient.FlattenToPlane = Projection.FlattenToPlane
Orient.MirrorAcrossPlane = Projection.MirrorAcrossPlane
Orient.SignedDistanceToPlane = Projection.SignedDistanceToPlane

-- Randomized Transform Generation
Orient.RandomPointInRadius = Random.RandomPointInRadius
Orient.RandomPointOnRadius = Random.RandomPointOnRadius
Orient.RandomPointInBox = Random.RandomPointInBox
Orient.RandomPointInBounds = Random.RandomPointInBounds
Orient.RandomOffset = Random.RandomOffset
Orient.RandomFlatOffset = Random.RandomFlatOffset
Orient.RandomYaw = Random.RandomYaw
Orient.RandomYawCFrame = Random.RandomYawCFrame
Orient.RandomizedYaw = Random.RandomizedYaw
Orient.RandomPointOnArc = Random.RandomPointOnArc
Orient.RandomPointInAnnulus = Random.RandomPointInAnnulus
Orient.RandomPointInFrontArc = Random.RandomPointInFrontArc
Orient.RandomTransformInBox = Random.RandomTransformInBox

-- Conversion / Decomposition
Orient.GetPosition = Conversion.GetPosition
Orient.GetX = Conversion.GetX
Orient.GetY = Conversion.GetY
Orient.GetZ = Conversion.GetZ
Orient.GetComponents = Conversion.GetComponents
Orient.ToObjectSpace = Conversion.ToObjectSpace
Orient.ToWorldSpace = Conversion.ToWorldSpace
Orient.PointToObjectSpace = Conversion.PointToObjectSpace
Orient.PointToWorldSpace = Conversion.PointToWorldSpace
Orient.VectorToObjectSpace = Conversion.VectorToObjectSpace
Orient.VectorToWorldSpace = Conversion.VectorToWorldSpace
Orient.FromPosition = Conversion.FromPosition
Orient.FromPositionAndYaw = Conversion.FromPositionAndYaw
Orient.FromLookVector = Conversion.FromLookVector
Orient.FromFlatLookVector = Conversion.FromFlatLookVector
Orient.WithRotation = Conversion.WithRotation
Orient.WithLookVector = Conversion.WithLookVector
Orient.WithFlatLookVector = Conversion.WithFlatLookVector

-- Validation / Comparison
Orient.NearlyEqual = Validation.NearlyEqual
Orient.NearlyEqualVector = Validation.NearlyEqualVector
Orient.NearlyEqualFlatVector = Validation.NearlyEqualFlatVector
Orient.NearlyEqualCFrame = Validation.NearlyEqualCFrame
Orient.IsZero = Validation.IsZero
Orient.IsZeroVector = Validation.IsZeroVector
Orient.IsZeroFlatVector = Validation.IsZeroFlatVector
Orient.IsDegenerateDirection = Validation.IsDegenerateDirection
Orient.IsSamePosition = Validation.IsSamePosition
Orient.IsSameYaw = Validation.IsSameYaw

return table.freeze(Orient)
