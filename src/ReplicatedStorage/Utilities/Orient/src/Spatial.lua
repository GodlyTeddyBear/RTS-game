--!strict

local Facing = require(script.Parent.Facing)

local function _FlatVector(vector: Vector3): Vector3
	return Vector3.new(vector.X, 0, vector.Z)
end

local function _AngleBetweenVectors(a: Vector3, b: Vector3): number?
	local aUnit = Facing.SafeUnit(a)
	local bUnit = Facing.SafeUnit(b)
	if aUnit == nil or bUnit == nil then
		return nil
	end

	return math.acos(math.clamp(aUnit:Dot(bUnit), -1, 1))
end

--[=[
    @class OrientSpatial
    Spatial relationship helpers for `Orient`.

    Use this module for distance checks, directional offsets, relative
    orientation tests, and angle comparisons between points and transforms.
    @server
    @client
]=]
local Spatial = {}

-- Distance helpers
function Spatial.Distance(a: Vector3, b: Vector3): number
	return (b - a).Magnitude
end

function Spatial.DistanceSquared(a: Vector3, b: Vector3): number
	local delta = b - a
	return delta:Dot(delta)
end

function Spatial.FlatDistance(a: Vector3, b: Vector3): number
	return _FlatVector(b - a).Magnitude
end

function Spatial.FlatDistanceSquared(a: Vector3, b: Vector3): number
	local delta = _FlatVector(b - a)
	return delta:Dot(delta)
end

function Spatial.IsWithinRange(a: Vector3, b: Vector3, range: number): boolean
	return Spatial.DistanceSquared(a, b) <= range * range
end

function Spatial.IsWithinFlatRange(a: Vector3, b: Vector3, range: number): boolean
	return Spatial.FlatDistanceSquared(a, b) <= range * range
end

-- Projection helpers
function Spatial.ProjectToXZ(position: Vector3): Vector3
	return Vector3.new(position.X, 0, position.Z)
end

function Spatial.ProjectToY(position: Vector3, y: number): Vector3
	return Vector3.new(position.X, y, position.Z)
end

function Spatial.FlattenToHeight(position: Vector3, height: number): Vector3
	return Spatial.ProjectToY(position, height)
end

-- Basis vectors and offsets
function Spatial.GetForward(cframe: CFrame): Vector3
	return cframe.LookVector
end

function Spatial.GetRight(cframe: CFrame): Vector3
	return cframe.RightVector
end

function Spatial.GetUp(cframe: CFrame): Vector3
	return cframe.UpVector
end

function Spatial.GetFlatForward(cframe: CFrame): Vector3?
	return Facing.SafeUnit(_FlatVector(cframe.LookVector))
end

function Spatial.GetOffsetBetween(from: Vector3, to: Vector3): Vector3
	return to - from
end

function Spatial.GetLocalOffset(fromCFrame: CFrame, worldPosition: Vector3): Vector3
	return fromCFrame:PointToObjectSpace(worldPosition)
end

function Spatial.GetWorldOffset(fromCFrame: CFrame, localOffset: Vector3): Vector3
	return fromCFrame:PointToWorldSpace(localOffset)
end

-- Relative target tests
function Spatial.DotToTarget(observer: CFrame, targetPosition: Vector3): number
	local direction = targetPosition - observer.Position
	local directionUnit = Facing.SafeUnit(direction)
	if directionUnit == nil then
		return 0
	end

	return observer.LookVector:Dot(directionUnit)
end

function Spatial.FlatDotToTarget(observer: CFrame, targetPosition: Vector3): number
	local forward = Spatial.GetFlatForward(observer)
	local direction = Facing.GetFlatDirection(observer.Position, targetPosition)
	if forward == nil or direction == nil then
		return 0
	end

	return forward:Dot(direction)
end

function Spatial.IsInFront(observer: CFrame, targetPosition: Vector3): boolean
	return Spatial.DotToTarget(observer, targetPosition) > 0
end

function Spatial.IsBehind(observer: CFrame, targetPosition: Vector3): boolean
	return Spatial.DotToTarget(observer, targetPosition) < 0
end

function Spatial.IsLeftOf(observer: CFrame, targetPosition: Vector3): boolean
	local direction = targetPosition - observer.Position
	return observer.RightVector:Dot(direction) < 0
end

function Spatial.IsRightOf(observer: CFrame, targetPosition: Vector3): boolean
	local direction = targetPosition - observer.Position
	return observer.RightVector:Dot(direction) > 0
end

-- Angle helpers
function Spatial.AngleToTarget(observer: CFrame, targetPosition: Vector3): number?
	return _AngleBetweenVectors(observer.LookVector, targetPosition - observer.Position)
end

function Spatial.FlatAngleToTarget(observer: CFrame, targetPosition: Vector3): number?
	local forward = Spatial.GetFlatForward(observer)
	local direction = Facing.GetFlatDirection(observer.Position, targetPosition)
	if forward == nil or direction == nil then
		return nil
	end

	return _AngleBetweenVectors(forward, direction)
end

return table.freeze(Spatial)
