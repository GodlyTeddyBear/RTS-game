--!strict

local Conversion = require(script.Parent.Conversion)
local Facing = require(script.Parent.Facing)
local Validation = require(script.Parent.Validation)

type TGridSize = number | Vector3

local function _ResolveGridSize(gridSize: TGridSize): Vector3
	-- Normalize the caller input into per-axis steps before snapping.
	if type(gridSize) == "number" then
		Validation.AssertPositive(gridSize, "gridSize")
		return Vector3.new(gridSize, gridSize, gridSize)
	end

	assert(gridSize.X > 0 and gridSize.Y > 0 and gridSize.Z > 0, "Orient gridSize Vector3 must be positive")
	return gridSize
end

--[=[
    @class OrientSnapping
    Snapping and quantization helpers for `Orient`.

    This module rounds scalar values, positions, yaw angles, and combined
    transforms to a requested grid or angle step.
    @server
    @client
]=]
local Snapping = {}

-- Scalar and position snapping
--[=[
    Snaps a scalar to the nearest step.
    @within OrientSnapping
    @param value number -- The value to snap.
    @param step number -- The snap step.
    @return number -- The snapped value.
]=]
function Snapping.SnapScalar(value: number, step: number): number
	Validation.AssertPositive(step, "step")
	return math.round(value / step) * step
end

--[=[
    Snaps a position to a uniform or per-axis grid.
    @within OrientSnapping
    @param position Vector3 -- The position to snap.
    @param gridSize number | Vector3 -- The snap grid size.
    @return Vector3 -- The snapped position.
]=]
function Snapping.SnapPosition(position: Vector3, gridSize: TGridSize): Vector3
	local resolvedGridSize = _ResolveGridSize(gridSize)
	return Vector3.new(
		Snapping.SnapScalar(position.X, resolvedGridSize.X),
		Snapping.SnapScalar(position.Y, resolvedGridSize.Y),
		Snapping.SnapScalar(position.Z, resolvedGridSize.Z)
	)
end

-- Rotation snapping
--[=[
    Snaps only the position of a transform to a grid.
    @within OrientSnapping
    @param cframe CFrame -- The transform to snap.
    @param gridSize number | Vector3 -- The snap grid size.
    @return CFrame -- The transform with a snapped position.
]=]
function Snapping.SnapCFramePosition(cframe: CFrame, gridSize: TGridSize): CFrame
	local snappedPosition = Snapping.SnapPosition(cframe.Position, gridSize)
	return Conversion.WithRotation(snappedPosition, cframe)
end

--[=[
    Snaps an angle in radians to the nearest step.
    @within OrientSnapping
    @param angle number -- The angle to snap.
    @param stepRadians number -- The radian step.
    @return number -- The snapped angle.
]=]
function Snapping.SnapAngleRadians(angle: number, stepRadians: number): number
	Validation.AssertPositive(stepRadians, "stepRadians")
	return Snapping.SnapScalar(angle, stepRadians)
end

--[=[
    Snaps an angle in degrees to the nearest step.
    @within OrientSnapping
    @param angle number -- The angle to snap.
    @param stepDegrees number -- The degree step.
    @return number -- The snapped angle.
]=]
function Snapping.SnapAngleDegrees(angle: number, stepDegrees: number): number
	Validation.AssertPositive(stepDegrees, "stepDegrees")
	return Snapping.SnapScalar(angle, stepDegrees)
end

--[=[
    Snaps the yaw of a transform to a degree step.
    @within OrientSnapping
    @param cframe CFrame -- The transform to snap.
    @param angleStepDegrees number -- The yaw step in degrees.
    @return CFrame -- The transform with snapped yaw.
]=]
function Snapping.SnapYaw(cframe: CFrame, angleStepDegrees: number): CFrame
	Validation.AssertPositive(angleStepDegrees, "angleStepDegrees")
	local currentYaw = Facing.GetYaw(cframe)
	local snappedYaw = Snapping.SnapAngleRadians(currentYaw, math.rad(angleStepDegrees))
	return Facing.SetYaw(cframe, snappedYaw)
end

function Snapping.SnapRotationYaw(cframe: CFrame, angleStepDegrees: number): CFrame
	return Snapping.SnapYaw(cframe, angleStepDegrees)
end

-- Combined transform snapping
--[=[
    Snaps both position and yaw on a transform.
    @within OrientSnapping
    @param cframe CFrame -- The transform to snap.
    @param positionGridSize number | Vector3 -- The position grid size.
    @param angleStepDegrees number -- The yaw step in degrees.
    @return CFrame -- The snapped transform.
]=]
function Snapping.SnapTransform(cframe: CFrame, positionGridSize: TGridSize, angleStepDegrees: number): CFrame
	local snappedPosition = Snapping.SnapPosition(cframe.Position, positionGridSize)
	local snappedRotation = Snapping.SnapYaw(cframe, angleStepDegrees)
	return Conversion.WithRotation(snappedPosition, snappedRotation)
end

return table.freeze(Snapping)
