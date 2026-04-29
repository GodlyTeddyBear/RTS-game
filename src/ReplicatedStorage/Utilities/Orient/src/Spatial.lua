--!strict

local Facing = require(script.Parent.Facing)

local function _FlatVector(vector: Vector3): Vector3
	-- Drop the Y component so distance math stays on the XZ plane.
	return Vector3.new(vector.X, 0, vector.Z)
end

local function _AngleBetweenVectors(a: Vector3, b: Vector3): number?
	-- Return `nil` when either vector cannot produce a stable unit direction.
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
--[=[
    Returns the distance between two points.
    @within OrientSpatial
    @param a Vector3 -- The first point.
    @param b Vector3 -- The second point.
    @return number -- The distance.
]=]
function Spatial.Distance(a: Vector3, b: Vector3): number
	return (b - a).Magnitude
end

--[=[
    Returns the squared distance between two points.
    @within OrientSpatial
    @param a Vector3 -- The first point.
    @param b Vector3 -- The second point.
    @return number -- The squared distance.
]=]
function Spatial.DistanceSquared(a: Vector3, b: Vector3): number
	local delta = b - a
	return delta:Dot(delta)
end

--[=[
    Returns the flat distance between two points on the XZ plane.
    @within OrientSpatial
    @param a Vector3 -- The first point.
    @param b Vector3 -- The second point.
    @return number -- The flat distance.
]=]
function Spatial.FlatDistance(a: Vector3, b: Vector3): number
	return _FlatVector(b - a).Magnitude
end

--[=[
    Returns the squared flat distance between two points on the XZ plane.
    @within OrientSpatial
    @param a Vector3 -- The first point.
    @param b Vector3 -- The second point.
    @return number -- The squared flat distance.
]=]
function Spatial.FlatDistanceSquared(a: Vector3, b: Vector3): number
	local delta = _FlatVector(b - a)
	return delta:Dot(delta)
end

--[=[
    Checks whether two points are within a 3D range.
    @within OrientSpatial
    @param a Vector3 -- The first point.
    @param b Vector3 -- The second point.
    @param range number -- The maximum range.
    @return boolean -- Whether the points are within range.
]=]
function Spatial.IsWithinRange(a: Vector3, b: Vector3, range: number): boolean
	return Spatial.DistanceSquared(a, b) <= range * range
end

--[=[
    Checks whether two points are within a flat range on the XZ plane.
    @within OrientSpatial
    @param a Vector3 -- The first point.
    @param b Vector3 -- The second point.
    @param range number -- The maximum range.
    @return boolean -- Whether the points are within range.
]=]
function Spatial.IsWithinFlatRange(a: Vector3, b: Vector3, range: number): boolean
	return Spatial.FlatDistanceSquared(a, b) <= range * range
end

-- Projection helpers
--[=[
    Projects a position onto the XZ plane.
    @within OrientSpatial
    @param position Vector3 -- The position to project.
    @return Vector3 -- The projected position.
]=]
function Spatial.ProjectToXZ(position: Vector3): Vector3
	return Vector3.new(position.X, 0, position.Z)
end

--[=[
    Replaces the Y component of a position.
    @within OrientSpatial
    @param position Vector3 -- The position to update.
    @param y number -- The replacement height.
    @return Vector3 -- The updated position.
]=]
function Spatial.ProjectToY(position: Vector3, y: number): Vector3
	return Vector3.new(position.X, y, position.Z)
end

--[=[
    Flattens a position to a target height.
    @within OrientSpatial
    @param position Vector3 -- The position to flatten.
    @param height number -- The target height.
    @return Vector3 -- The flattened position.
]=]
function Spatial.FlattenToHeight(position: Vector3, height: number): Vector3
	return Spatial.ProjectToY(position, height)
end

-- Basis vectors and offsets
--[=[
    Returns the forward vector of a transform.
    @within OrientSpatial
    @param cframe CFrame -- The transform to inspect.
    @return Vector3 -- The forward vector.
]=]
function Spatial.GetForward(cframe: CFrame): Vector3
	return cframe.LookVector
end

--[=[
    Returns the right vector of a transform.
    @within OrientSpatial
    @param cframe CFrame -- The transform to inspect.
    @return Vector3 -- The right vector.
]=]
function Spatial.GetRight(cframe: CFrame): Vector3
	return cframe.RightVector
end

--[=[
    Returns the up vector of a transform.
    @within OrientSpatial
    @param cframe CFrame -- The transform to inspect.
    @return Vector3 -- The up vector.
]=]
function Spatial.GetUp(cframe: CFrame): Vector3
	return cframe.UpVector
end

--[=[
    Returns the forward vector flattened onto the XZ plane.
    @within OrientSpatial
    @param cframe CFrame -- The transform to inspect.
    @return Vector3? -- The flat forward vector, or `nil` when degenerate.
]=]
function Spatial.GetFlatForward(cframe: CFrame): Vector3?
	return Facing.SafeUnit(_FlatVector(cframe.LookVector))
end

--[=[
    Returns the offset from one point to another.
    @within OrientSpatial
    @param from Vector3 -- The starting point.
    @param to Vector3 -- The target point.
    @return Vector3 -- The offset vector.
]=]
function Spatial.GetOffsetBetween(from: Vector3, to: Vector3): Vector3
	return to - from
end

--[=[
    Converts a world position into local space.
    @within OrientSpatial
    @param fromCFrame CFrame -- The reference transform.
    @param worldPosition Vector3 -- The world position to convert.
    @return Vector3 -- The local-space position.
]=]
function Spatial.GetLocalOffset(fromCFrame: CFrame, worldPosition: Vector3): Vector3
	return fromCFrame:PointToObjectSpace(worldPosition)
end

--[=[
    Converts a local offset into world space.
    @within OrientSpatial
    @param fromCFrame CFrame -- The reference transform.
    @param localOffset Vector3 -- The local offset to convert.
    @return Vector3 -- The world-space position.
]=]
function Spatial.GetWorldOffset(fromCFrame: CFrame, localOffset: Vector3): Vector3
	return fromCFrame:PointToWorldSpace(localOffset)
end

-- Relative target tests
--[=[
    Returns the dot product between an observer's forward vector and the
    direction to a target.
    @within OrientSpatial
    @param observer CFrame -- The observing transform.
    @param targetPosition Vector3 -- The target position.
    @return number -- The facing dot product, or `0` for a degenerate target.
]=]
function Spatial.DotToTarget(observer: CFrame, targetPosition: Vector3): number
	local direction = targetPosition - observer.Position
	local directionUnit = Facing.SafeUnit(direction)
	if directionUnit == nil then
		return 0
	end

	return observer.LookVector:Dot(directionUnit)
end

--[=[
    Returns the flat dot product between an observer and a target.
    @within OrientSpatial
    @param observer CFrame -- The observing transform.
    @param targetPosition Vector3 -- The target position.
    @return number -- The flat facing dot product, or `0` for a degenerate target.
]=]
function Spatial.FlatDotToTarget(observer: CFrame, targetPosition: Vector3): number
	local forward = Spatial.GetFlatForward(observer)
	local direction = Facing.GetFlatDirection(observer.Position, targetPosition)
	if forward == nil or direction == nil then
		return 0
	end

	return forward:Dot(direction)
end

--[=[
    Checks whether a target is in front of an observer.
    @within OrientSpatial
    @param observer CFrame -- The observing transform.
    @param targetPosition Vector3 -- The target position.
    @return boolean -- Whether the target is in front.
]=]
function Spatial.IsInFront(observer: CFrame, targetPosition: Vector3): boolean
	return Spatial.DotToTarget(observer, targetPosition) > 0
end

--[=[
    Checks whether a target is behind an observer.
    @within OrientSpatial
    @param observer CFrame -- The observing transform.
    @param targetPosition Vector3 -- The target position.
    @return boolean -- Whether the target is behind.
]=]
function Spatial.IsBehind(observer: CFrame, targetPosition: Vector3): boolean
	return Spatial.DotToTarget(observer, targetPosition) < 0
end

--[=[
    Checks whether a target is to the left of an observer.
    @within OrientSpatial
    @param observer CFrame -- The observing transform.
    @param targetPosition Vector3 -- The target position.
    @return boolean -- Whether the target is left of the observer.
]=]
function Spatial.IsLeftOf(observer: CFrame, targetPosition: Vector3): boolean
	local direction = targetPosition - observer.Position
	return observer.RightVector:Dot(direction) < 0
end

--[=[
    Checks whether a target is to the right of an observer.
    @within OrientSpatial
    @param observer CFrame -- The observing transform.
    @param targetPosition Vector3 -- The target position.
    @return boolean -- Whether the target is right of the observer.
]=]
function Spatial.IsRightOf(observer: CFrame, targetPosition: Vector3): boolean
	local direction = targetPosition - observer.Position
	return observer.RightVector:Dot(direction) > 0
end

-- Angle helpers
--[=[
    Returns the angle between an observer's forward vector and the target.
    @within OrientSpatial
    @param observer CFrame -- The observing transform.
    @param targetPosition Vector3 -- The target position.
    @return number? -- The angle in radians, or `nil` for degenerate input.
]=]
function Spatial.AngleToTarget(observer: CFrame, targetPosition: Vector3): number?
	return _AngleBetweenVectors(observer.LookVector, targetPosition - observer.Position)
end

--[=[
    Returns the flat angle between an observer and the target.
    @within OrientSpatial
    @param observer CFrame -- The observing transform.
    @param targetPosition Vector3 -- The target position.
    @return number? -- The angle in radians, or `nil` for degenerate input.
]=]
function Spatial.FlatAngleToTarget(observer: CFrame, targetPosition: Vector3): number?
	local forward = Spatial.GetFlatForward(observer)
	local direction = Facing.GetFlatDirection(observer.Position, targetPosition)
	if forward == nil or direction == nil then
		return nil
	end

	return _AngleBetweenVectors(forward, direction)
end

return table.freeze(Spatial)
