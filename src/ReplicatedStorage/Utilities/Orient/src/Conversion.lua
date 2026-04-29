--!strict

local Constants = require(script.Parent.Constants)

local DEGENERATE_EPSILON = Constants.DEGENERATE_EPSILON

local function _GetRotationOnly(cframe: CFrame): CFrame
	-- Remove translation so only the basis rotation remains.
	return cframe - cframe.Position
end

--[=[
    @class OrientConversion
    Conversion and decomposition helpers for `Orient`.

    Use this module when you need to read, rebuild, or swap pieces of a
    `CFrame` without changing its semantic position or rotation.
    @server
    @client
]=]
local Conversion = {}

-- Component access
--[=[
    Returns the world position of a `CFrame`.
    @within OrientConversion
    @param cframe CFrame -- The transform to read.
    @return Vector3 -- The transform position.
]=]
function Conversion.GetPosition(cframe: CFrame): Vector3
	return cframe.Position
end

--[=[
    Returns the X component of a `CFrame` position.
    @within OrientConversion
    @param cframe CFrame -- The transform to read.
    @return number -- The X position component.
]=]
function Conversion.GetX(cframe: CFrame): number
	return cframe.Position.X
end

--[=[
    Returns the Y component of a `CFrame` position.
    @within OrientConversion
    @param cframe CFrame -- The transform to read.
    @return number -- The Y position component.
]=]
function Conversion.GetY(cframe: CFrame): number
	return cframe.Position.Y
end

--[=[
    Returns the Z component of a `CFrame` position.
    @within OrientConversion
    @param cframe CFrame -- The transform to read.
    @return number -- The Z position component.
]=]
function Conversion.GetZ(cframe: CFrame): number
	return cframe.Position.Z
end

--[=[
    Returns the position and rotation components of a `CFrame`.
    @within OrientConversion
    @param cframe CFrame -- The transform to decompose.
    @return Vector3 -- The world position.
    @return CFrame -- The rotation-only transform.
]=]
function Conversion.GetComponents(cframe: CFrame): (Vector3, CFrame)
	return cframe.Position, _GetRotationOnly(cframe)
end

-- Space conversions
--[=[
    Converts a transform into the object space of another `CFrame`.
    @within OrientConversion
    @param from CFrame -- The reference frame.
    @param target CFrame -- The transform to convert.
    @return CFrame -- The target in `from`'s local space.
]=]
function Conversion.ToObjectSpace(from: CFrame, target: CFrame): CFrame
	return from:ToObjectSpace(target)
end

--[=[
    Converts a local transform back into world space.
    @within OrientConversion
    @param from CFrame -- The reference frame.
    @param localTransform CFrame -- The local transform to convert.
    @return CFrame -- The transform in world space.
]=]
function Conversion.ToWorldSpace(from: CFrame, localTransform: CFrame): CFrame
	return from:ToWorldSpace(localTransform)
end

--[=[
    Converts a world point into the local space of a `CFrame`.
    @within OrientConversion
    @param from CFrame -- The reference frame.
    @param worldPoint Vector3 -- The point to convert.
    @return Vector3 -- The point in local space.
]=]
function Conversion.PointToObjectSpace(from: CFrame, worldPoint: Vector3): Vector3
	return from:PointToObjectSpace(worldPoint)
end

--[=[
    Converts a local point into world space.
    @within OrientConversion
    @param from CFrame -- The reference frame.
    @param localPoint Vector3 -- The local point to convert.
    @return Vector3 -- The point in world space.
]=]
function Conversion.PointToWorldSpace(from: CFrame, localPoint: Vector3): Vector3
	return from:PointToWorldSpace(localPoint)
end

--[=[
    Converts a world vector into the local space of a `CFrame`.
    @within OrientConversion
    @param from CFrame -- The reference frame.
    @param worldVector Vector3 -- The vector to convert.
    @return Vector3 -- The vector in local space.
]=]
function Conversion.VectorToObjectSpace(from: CFrame, worldVector: Vector3): Vector3
	return from:VectorToObjectSpace(worldVector)
end

--[=[
    Converts a local vector into world space.
    @within OrientConversion
    @param from CFrame -- The reference frame.
    @param localVector Vector3 -- The local vector to convert.
    @return Vector3 -- The vector in world space.
]=]
function Conversion.VectorToWorldSpace(from: CFrame, localVector: Vector3): Vector3
	return from:VectorToWorldSpace(localVector)
end

-- Constructors
--[=[
    Builds a translation-only `CFrame` from a position.
    @within OrientConversion
    @param position Vector3 -- The world position.
    @return CFrame -- A `CFrame` at `position` with identity rotation.
]=]
function Conversion.FromPosition(position: Vector3): CFrame
	return CFrame.new(position)
end

--[=[
    Builds a `CFrame` from a position and yaw angle.
    @within OrientConversion
    @param position Vector3 -- The world position.
    @param yawRadians number -- The yaw rotation in radians.
    @return CFrame -- The constructed transform.
]=]
function Conversion.FromPositionAndYaw(position: Vector3, yawRadians: number): CFrame
	return CFrame.new(position) * CFrame.Angles(0, yawRadians, 0)
end

--[=[
    Builds a `CFrame` from a position and look vector.
    @within OrientConversion
    @param position Vector3 -- The world position.
    @param lookVector Vector3 -- The forward direction.
    @return CFrame? -- The transform, or `nil` for a degenerate vector.
]=]
function Conversion.FromLookVector(position: Vector3, lookVector: Vector3): CFrame?
	-- Reject zero-length inputs so `CFrame.lookAt` never receives invalid direction data.
	if lookVector.Magnitude <= DEGENERATE_EPSILON then
		return nil
	end

	return CFrame.lookAt(position, position + lookVector)
end

--[=[
    Builds a `CFrame` from a position and flat look vector.
    @within OrientConversion
    @param position Vector3 -- The world position.
    @param lookVector Vector3 -- The direction to flatten into the XZ plane.
    @return CFrame? -- The transform, or `nil` for a degenerate vector.
]=]
function Conversion.FromFlatLookVector(position: Vector3, lookVector: Vector3): CFrame?
	local flatLookVector = Vector3.new(lookVector.X, 0, lookVector.Z)
	return Conversion.FromLookVector(position, flatLookVector)
end

-- Rotation replacement
--[=[
    Replaces the translation of a rotation-only `CFrame`.
    @within OrientConversion
    @param position Vector3 -- The new world position.
    @param rotation CFrame -- The rotation to keep.
    @return CFrame -- A transform using `position` and `rotation`.
]=]
function Conversion.WithRotation(position: Vector3, rotation: CFrame): CFrame
	return CFrame.new(position) * _GetRotationOnly(rotation)
end

--[=[
    Rebuilds a `CFrame` at a position while preserving its look vector.
    @within OrientConversion
    @param position Vector3 -- The new world position.
    @param lookVector Vector3 -- The forward direction to preserve.
    @return CFrame? -- The rebuilt transform, or `nil` for a degenerate vector.
]=]
function Conversion.WithLookVector(position: Vector3, lookVector: Vector3): CFrame?
	return Conversion.FromLookVector(position, lookVector)
end

--[=[
    Rebuilds a `CFrame` at a position while preserving its flat look vector.
    @within OrientConversion
    @param position Vector3 -- The new world position.
    @param lookVector Vector3 -- The forward direction to flatten and preserve.
    @return CFrame? -- The rebuilt transform, or `nil` for a degenerate vector.
]=]
function Conversion.WithFlatLookVector(position: Vector3, lookVector: Vector3): CFrame?
	return Conversion.FromFlatLookVector(position, lookVector)
end

return table.freeze(Conversion)
