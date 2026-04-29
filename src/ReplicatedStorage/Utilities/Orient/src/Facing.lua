--!strict

local Constants = require(script.Parent.Constants)
local Conversion = require(script.Parent.Conversion)

local DEGENERATE_EPSILON = Constants.DEGENERATE_EPSILON
local TAU = Constants.TAU

local function _NormalizeAngle(angleRadians: number): number
	-- Wrap the angle into `[-pi, pi]` so yaw setters stay stable around 0.
	local normalized = angleRadians % TAU
	if normalized > math.pi then
		return normalized - TAU
	end
	return normalized
end

--[=[
    @class OrientFacing
    Facing and orientation helpers for `Orient`.

    This module handles direction lookup, look-at construction, and yaw
    extraction or replacement on existing transforms.
    @server
    @client
]=]
local Facing = {}

-- Rotation extraction
--[=[
    Returns the rotation-only portion of a `CFrame`.
    @within OrientFacing
    @param cframe CFrame -- The transform to split.
    @return CFrame -- The transform with translation removed.
]=]
function Facing.GetRotation(cframe: CFrame): CFrame
	return cframe - cframe.Position
end

-- Look-at construction
--[=[
    Rebuilds a `CFrame` from a position and rotation-only transform.
    @within OrientFacing
    @param position Vector3 -- The new world position.
    @param rotation CFrame -- The rotation to reuse.
    @return CFrame -- The combined transform.
]=]
function Facing.BuildFromRotation(position: Vector3, rotation: CFrame): CFrame
	return Conversion.WithRotation(position, rotation)
end

--[=[
    Builds a look-at `CFrame` from two world positions.
    @within OrientFacing
    @param fromPosition Vector3 -- The origin position.
    @param toPosition Vector3 -- The target position.
    @return CFrame? -- The look-at transform, or `nil` when the points coincide.
]=]
function Facing.BuildLookAt(fromPosition: Vector3, toPosition: Vector3): CFrame?
	-- Reject degenerate vectors so the caller can handle the failure explicitly.
	local direction = toPosition - fromPosition
	if direction.Magnitude <= DEGENERATE_EPSILON then
		return nil
	end

	return CFrame.lookAt(fromPosition, toPosition)
end

--[=[
    Builds a look-at `CFrame` that ignores vertical offset in the target.
    @within OrientFacing
    @param fromPosition Vector3 -- The origin position.
    @param toPosition Vector3 -- The target position.
    @return CFrame? -- The flat look-at transform, or `nil` when degenerate.
]=]
function Facing.BuildFlatLookAt(fromPosition: Vector3, toPosition: Vector3): CFrame?
	local flatTarget = Vector3.new(toPosition.X, fromPosition.Y, toPosition.Z)
	return Facing.BuildLookAt(fromPosition, flatTarget)
end

-- Direction vectors
--[=[
    Returns a unit vector from one world position toward another.
    @within OrientFacing
    @param fromPosition Vector3 -- The origin position.
    @param toPosition Vector3 -- The target position.
    @return Vector3? -- The normalized direction, or `nil` when degenerate.
]=]
function Facing.GetDirection(fromPosition: Vector3, toPosition: Vector3): Vector3?
	-- Reuse the same degeneracy guard as the look-at helpers.
	local direction = toPosition - fromPosition
	if direction.Magnitude <= DEGENERATE_EPSILON then
		return nil
	end

	return direction.Unit
end

--[=[
    Returns a unit direction flattened onto the XZ plane.
    @within OrientFacing
    @param fromPosition Vector3 -- The origin position.
    @param toPosition Vector3 -- The target position.
    @return Vector3? -- The flattened unit direction, or `nil` when degenerate.
]=]
function Facing.GetFlatDirection(fromPosition: Vector3, toPosition: Vector3): Vector3?
	local direction = Vector3.new(toPosition.X - fromPosition.X, 0, toPosition.Z - fromPosition.Z)
	return Facing.SafeUnit(direction)
end

--[=[
    Safely normalizes a direction vector.
    @within OrientFacing
    @param direction Vector3 -- The vector to normalize.
    @return Vector3? -- The unit vector, or `nil` for near-zero input.
]=]
function Facing.SafeUnit(direction: Vector3): Vector3?
	if direction.Magnitude <= DEGENERATE_EPSILON then
		return nil
	end

	return direction.Unit
end

-- Yaw helpers
--[=[
    Rotates a transform around its world position by a yaw offset.
    @within OrientFacing
    @param cframe CFrame -- The transform to rotate.
    @param yawRadians number -- The yaw delta in radians.
    @return CFrame -- The rotated transform.
]=]
function Facing.RotateYaw(cframe: CFrame, yawRadians: number): CFrame
	return CFrame.new(cframe.Position) * CFrame.Angles(0, yawRadians, 0) * Facing.GetRotation(cframe)
end

--[=[
    Extracts the yaw angle from a rotation-only `CFrame`.
    @within OrientFacing
    @param rotation CFrame -- The rotation to inspect.
    @return number -- The yaw angle in radians.
]=]
function Facing.GetYaw(rotation: CFrame): number
	local lookVector = rotation.LookVector
	return math.atan2(-lookVector.X, -lookVector.Z)
end

--[=[
    Replaces the yaw of a transform while preserving position.
    @within OrientFacing
    @param cframe CFrame -- The transform to update.
    @param yawRadians number -- The new yaw angle in radians.
    @return CFrame -- The transform with the new yaw applied.
]=]
function Facing.SetYaw(cframe: CFrame, yawRadians: number): CFrame
	return Conversion.FromPositionAndYaw(cframe.Position, _NormalizeAngle(yawRadians))
end

return table.freeze(Facing)
