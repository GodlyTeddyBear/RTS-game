--!strict

local Constants = require(script.Parent.Constants)
local Conversion = require(script.Parent.Conversion)

local DEGENERATE_EPSILON = Constants.DEGENERATE_EPSILON
local TAU = Constants.TAU

local function _NormalizeAngle(angleRadians: number): number
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
function Facing.GetRotation(cframe: CFrame): CFrame
	return cframe - cframe.Position
end

-- Look-at construction
function Facing.BuildFromRotation(position: Vector3, rotation: CFrame): CFrame
	return Conversion.WithRotation(position, rotation)
end

function Facing.BuildLookAt(fromPosition: Vector3, toPosition: Vector3): CFrame?
	local direction = toPosition - fromPosition
	if direction.Magnitude <= DEGENERATE_EPSILON then
		return nil
	end

	return CFrame.lookAt(fromPosition, toPosition)
end

function Facing.BuildFlatLookAt(fromPosition: Vector3, toPosition: Vector3): CFrame?
	local flatTarget = Vector3.new(toPosition.X, fromPosition.Y, toPosition.Z)
	return Facing.BuildLookAt(fromPosition, flatTarget)
end

-- Direction vectors
function Facing.GetDirection(fromPosition: Vector3, toPosition: Vector3): Vector3?
	local direction = toPosition - fromPosition
	if direction.Magnitude <= DEGENERATE_EPSILON then
		return nil
	end

	return direction.Unit
end

function Facing.GetFlatDirection(fromPosition: Vector3, toPosition: Vector3): Vector3?
	local direction = Vector3.new(toPosition.X - fromPosition.X, 0, toPosition.Z - fromPosition.Z)
	return Facing.SafeUnit(direction)
end

function Facing.SafeUnit(direction: Vector3): Vector3?
	if direction.Magnitude <= DEGENERATE_EPSILON then
		return nil
	end

	return direction.Unit
end

-- Yaw helpers
function Facing.RotateYaw(cframe: CFrame, yawRadians: number): CFrame
	return CFrame.new(cframe.Position) * CFrame.Angles(0, yawRadians, 0) * Facing.GetRotation(cframe)
end

function Facing.GetYaw(rotation: CFrame): number
	local lookVector = rotation.LookVector
	return math.atan2(-lookVector.X, -lookVector.Z)
end

function Facing.SetYaw(cframe: CFrame, yawRadians: number): CFrame
	return Conversion.FromPositionAndYaw(cframe.Position, _NormalizeAngle(yawRadians))
end

return table.freeze(Facing)
