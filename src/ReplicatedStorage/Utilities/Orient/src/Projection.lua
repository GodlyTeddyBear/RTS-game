--!strict

local Conversion = require(script.Parent.Conversion)
local Facing = require(script.Parent.Facing)
local Validation = require(script.Parent.Validation)

local function _ProjectScalar(vector: Vector3, ontoUnit: Vector3): number
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
function Projection.ProjectPointToPlane(point: Vector3, planePoint: Vector3, planeNormal: Vector3): Vector3?
	local normalUnit = Facing.SafeUnit(planeNormal)
	if normalUnit == nil then
		return nil
	end

	local offset = point - planePoint
	return point - normalUnit * offset:Dot(normalUnit)
end

function Projection.ProjectVectorToPlane(vector: Vector3, planeNormal: Vector3): Vector3?
	local normalUnit = Facing.SafeUnit(planeNormal)
	if normalUnit == nil then
		return nil
	end

	return vector - normalUnit * vector:Dot(normalUnit)
end

function Projection.ProjectPointToLine(point: Vector3, lineOrigin: Vector3, lineDirection: Vector3): Vector3?
	local directionUnit = Facing.SafeUnit(lineDirection)
	if directionUnit == nil then
		return nil
	end

	local t = _ProjectScalar(point - lineOrigin, directionUnit)
	return lineOrigin + directionUnit * t
end

function Projection.ClosestPointOnSegment(point: Vector3, segmentStart: Vector3, segmentEnd: Vector3): Vector3
	local segment = segmentEnd - segmentStart
	local lengthSquared = segment:Dot(segment)
	if lengthSquared <= 0 then
		return segmentStart
	end

	local t = math.clamp((point - segmentStart):Dot(segment) / lengthSquared, 0, 1)
	return segmentStart + segment * t
end

function Projection.ClosestPointOnRay(point: Vector3, rayOrigin: Vector3, rayDirection: Vector3): Vector3?
	local directionUnit = Facing.SafeUnit(rayDirection)
	if directionUnit == nil then
		return nil
	end

	local t = math.max(0, _ProjectScalar(point - rayOrigin, directionUnit))
	return rayOrigin + directionUnit * t
end

-- Position clamping
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

function Projection.ClampY(position: Vector3, minY: number, maxY: number): Vector3
	return Vector3.new(position.X, math.clamp(position.Y, minY, maxY), position.Z)
end

-- Magnitude and height helpers
function Projection.ClampMagnitude(vector: Vector3, maxMagnitude: number): Vector3
	Validation.AssertNonNegative(maxMagnitude, "maxMagnitude")
	local magnitude = vector.Magnitude
	if magnitude <= maxMagnitude or magnitude <= 0 then
		return vector
	end
	return vector.Unit * maxMagnitude
end

function Projection.SetHeight(position: Vector3, y: number): Vector3
	return Vector3.new(position.X, y, position.Z)
end

function Projection.SetCFrameHeight(cframe: CFrame, y: number): CFrame
	return Conversion.WithRotation(Vector3.new(cframe.Position.X, y, cframe.Position.Z), cframe)
end

function Projection.FlattenToPlane(point: Vector3, planeY: number): Vector3
	return Projection.SetHeight(point, planeY)
end

-- Plane reflection
function Projection.MirrorAcrossPlane(point: Vector3, planePoint: Vector3, planeNormal: Vector3): Vector3?
	local normalUnit = Facing.SafeUnit(planeNormal)
	if normalUnit == nil then
		return nil
	end

	local signedDistance = (point - planePoint):Dot(normalUnit)
	return point - normalUnit * (2 * signedDistance)
end

function Projection.SignedDistanceToPlane(point: Vector3, planePoint: Vector3, planeNormal: Vector3): number?
	local normalUnit = Facing.SafeUnit(planeNormal)
	if normalUnit == nil then
		return nil
	end

	return (point - planePoint):Dot(normalUnit)
end

return table.freeze(Projection)
