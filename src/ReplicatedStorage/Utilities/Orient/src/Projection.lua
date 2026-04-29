--!strict

local Conversion = require(script.Parent.Conversion)
local Facing = require(script.Parent.Facing)
local Validation = require(script.Parent.Validation)

local function _ProjectScalar(vector: Vector3, ontoUnit: Vector3): number
	-- Project `vector` onto an already-normalized direction.
	return vector:Dot(ontoUnit)
end

--[=[
    @class OrientProjection
    Plane, projection, and clamping helpers for `Orient`.

    Use this module to project points or vectors onto planes and lines, clamp
    positions or magnitudes, and mirror or flatten transforms into a target
    space.
    @server
    @client
]=]
local Projection = {}

-- Plane and line projection
--[=[
    Projects a point onto a plane.
    @within OrientProjection
    @param point Vector3 -- The point to project.
    @param planePoint Vector3 -- A point on the plane.
    @param planeNormal Vector3 -- The plane normal.
    @return Vector3? -- The projected point, or `nil` for a degenerate normal.
]=]
function Projection.ProjectPointToPlane(point: Vector3, planePoint: Vector3, planeNormal: Vector3): Vector3?
	local normalUnit = Facing.SafeUnit(planeNormal)
	if normalUnit == nil then
		return nil
	end

	local offset = point - planePoint
	return point - normalUnit * offset:Dot(normalUnit)
end

--[=[
    Projects a vector onto a plane.
    @within OrientProjection
    @param vector Vector3 -- The vector to project.
    @param planeNormal Vector3 -- The plane normal.
    @return Vector3? -- The projected vector, or `nil` for a degenerate normal.
]=]
function Projection.ProjectVectorToPlane(vector: Vector3, planeNormal: Vector3): Vector3?
	local normalUnit = Facing.SafeUnit(planeNormal)
	if normalUnit == nil then
		return nil
	end

	return vector - normalUnit * vector:Dot(normalUnit)
end

--[=[
    Projects a point onto an infinite line.
    @within OrientProjection
    @param point Vector3 -- The point to project.
    @param lineOrigin Vector3 -- A point on the line.
    @param lineDirection Vector3 -- The line direction.
    @return Vector3? -- The projected point, or `nil` for a degenerate direction.
]=]
function Projection.ProjectPointToLine(point: Vector3, lineOrigin: Vector3, lineDirection: Vector3): Vector3?
	local directionUnit = Facing.SafeUnit(lineDirection)
	if directionUnit == nil then
		return nil
	end

	local t = _ProjectScalar(point - lineOrigin, directionUnit)
	return lineOrigin + directionUnit * t
end

--[=[
    Returns the closest point on a finite segment.
    @within OrientProjection
    @param point Vector3 -- The point to measure from.
    @param segmentStart Vector3 -- The segment start.
    @param segmentEnd Vector3 -- The segment end.
    @return Vector3 -- The closest point on the segment.
]=]
function Projection.ClosestPointOnSegment(point: Vector3, segmentStart: Vector3, segmentEnd: Vector3): Vector3
	-- Handle a collapsed segment by returning its only endpoint.
	local segment = segmentEnd - segmentStart
	local lengthSquared = segment:Dot(segment)
	if lengthSquared <= 0 then
		return segmentStart
	end

	local t = math.clamp((point - segmentStart):Dot(segment) / lengthSquared, 0, 1)
	return segmentStart + segment * t
end

--[=[
    Returns the closest point on a ray.
    @within OrientProjection
    @param point Vector3 -- The point to measure from.
    @param rayOrigin Vector3 -- The ray origin.
    @param rayDirection Vector3 -- The ray direction.
    @return Vector3? -- The closest point, or `nil` for a degenerate direction.
]=]
function Projection.ClosestPointOnRay(point: Vector3, rayOrigin: Vector3, rayDirection: Vector3): Vector3?
	local directionUnit = Facing.SafeUnit(rayDirection)
	if directionUnit == nil then
		return nil
	end

	local t = math.max(0, _ProjectScalar(point - rayOrigin, directionUnit))
	return rayOrigin + directionUnit * t
end

-- Position clamping
--[=[
    Clamps a position inside axis-aligned world bounds.
    @within OrientProjection
    @param position Vector3 -- The position to clamp.
    @param minBounds Vector3 -- The minimum corner.
    @param maxBounds Vector3 -- The maximum corner.
    @return Vector3 -- The clamped position.
]=]
function Projection.ClampPosition(position: Vector3, minBounds: Vector3, maxBounds: Vector3): Vector3
	return Vector3.new(
		math.clamp(position.X, minBounds.X, maxBounds.X),
		math.clamp(position.Y, minBounds.Y, maxBounds.Y),
		math.clamp(position.Z, minBounds.Z, maxBounds.Z)
	)
end

function Projection.ClampXZ(position: Vector3, minX: number, maxX: number, minZ: number, maxZ: number): Vector3
	return Vector3.new(math.clamp(position.X, minX, maxX), position.Y, math.clamp(position.Z, minZ, maxZ))
end

--[=[
    Clamps only the Y component of a position.
    @within OrientProjection
    @param position Vector3 -- The position to clamp.
    @param minY number -- The minimum Y value.
    @param maxY number -- The maximum Y value.
    @return Vector3 -- The clamped position.
]=]
function Projection.ClampY(position: Vector3, minY: number, maxY: number): Vector3
	return Vector3.new(position.X, math.clamp(position.Y, minY, maxY), position.Z)
end

-- Magnitude and height helpers
--[=[
    Clamps a vector's magnitude to a maximum length.
    @within OrientProjection
    @param vector Vector3 -- The vector to clamp.
    @param maxMagnitude number -- The maximum magnitude.
    @return Vector3 -- The clamped vector.
]=]
function Projection.ClampMagnitude(vector: Vector3, maxMagnitude: number): Vector3
	Validation.AssertNonNegative(maxMagnitude, "maxMagnitude")
	local magnitude = vector.Magnitude
	if magnitude <= maxMagnitude or magnitude <= 0 then
		return vector
	end
	return vector.Unit * maxMagnitude
end

--[=[
    Replaces the Y component of a position.
    @within OrientProjection
    @param position Vector3 -- The position to update.
    @param y number -- The replacement height.
    @return Vector3 -- The updated position.
]=]
function Projection.SetHeight(position: Vector3, y: number): Vector3
	return Vector3.new(position.X, y, position.Z)
end

--[=[
    Replaces the Y component of a transform while preserving rotation.
    @within OrientProjection
    @param cframe CFrame -- The transform to update.
    @param y number -- The replacement height.
    @return CFrame -- The updated transform.
]=]
function Projection.SetCFrameHeight(cframe: CFrame, y: number): CFrame
	return Conversion.WithRotation(Vector3.new(cframe.Position.X, y, cframe.Position.Z), cframe)
end

--[=[
    Flattens a point onto a horizontal plane.
    @within OrientProjection
    @param point Vector3 -- The point to flatten.
    @param planeY number -- The plane height.
    @return Vector3 -- The flattened point.
]=]
function Projection.FlattenToPlane(point: Vector3, planeY: number): Vector3
	return Projection.SetHeight(point, planeY)
end

-- Plane reflection
--[=[
    Mirrors a point across a plane.
    @within OrientProjection
    @param point Vector3 -- The point to mirror.
    @param planePoint Vector3 -- A point on the plane.
    @param planeNormal Vector3 -- The plane normal.
    @return Vector3? -- The mirrored point, or `nil` for a degenerate normal.
]=]
function Projection.MirrorAcrossPlane(point: Vector3, planePoint: Vector3, planeNormal: Vector3): Vector3?
	local normalUnit = Facing.SafeUnit(planeNormal)
	if normalUnit == nil then
		return nil
	end

	local signedDistance = (point - planePoint):Dot(normalUnit)
	return point - normalUnit * (2 * signedDistance)
end

--[=[
    Returns the signed distance from a point to a plane.
    @within OrientProjection
    @param point Vector3 -- The point to measure.
    @param planePoint Vector3 -- A point on the plane.
    @param planeNormal Vector3 -- The plane normal.
    @return number? -- The signed distance, or `nil` for a degenerate normal.
]=]
function Projection.SignedDistanceToPlane(point: Vector3, planePoint: Vector3, planeNormal: Vector3): number?
	local normalUnit = Facing.SafeUnit(planeNormal)
	if normalUnit == nil then
		return nil
	end

	return (point - planePoint):Dot(normalUnit)
end

return table.freeze(Projection)
