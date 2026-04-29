--!strict

local Facing = require(script.Parent.Facing)
local Validation = require(script.Parent.Validation)

local function _BlendAlpha(speed: number, dt: number): number
	-- Convert a speed and timestep into an exponential blend factor.
	Validation.AssertNonNegative(speed, "speed")
	Validation.AssertNonNegative(dt, "dt")
	return 1 - math.exp(-speed * dt)
end

local function _LerpAngleRadians(fromAngle: number, toAngle: number, alpha: number): number
	-- Interpolate across the shortest wrapped angle delta.
	local delta = math.atan2(math.sin(toAngle - fromAngle), math.cos(toAngle - fromAngle))
	return fromAngle + delta * alpha
end

--[=[
    @class OrientInterpolation
    Interpolation and blending helpers for `Orient`.

    Use this module for smooth transitions between positions, transforms,
    rotations, and look-at targets.
    @server
    @client
]=]
local Interpolation = {}

-- Direct lerps
--[=[
    Linearly interpolates between two positions.
    @within OrientInterpolation
    @param from Vector3 -- The starting position.
    @param to Vector3 -- The target position.
    @param alpha number -- The interpolation factor.
    @return Vector3 -- The blended position.
]=]
function Interpolation.LerpPosition(from: Vector3, to: Vector3, alpha: number): Vector3
	return from:Lerp(to, alpha)
end

--[=[
    Linearly interpolates between two transforms.
    @within OrientInterpolation
    @param from CFrame -- The starting transform.
    @param to CFrame -- The target transform.
    @param alpha number -- The interpolation factor.
    @return CFrame -- The blended transform.
]=]
function Interpolation.LerpCFrame(from: CFrame, to: CFrame, alpha: number): CFrame
	return from:Lerp(to, alpha)
end

--[=[
    Interpolates only the rotation component between two transforms.
    @within OrientInterpolation
    @param from CFrame -- The starting transform.
    @param to CFrame -- The target transform.
    @param alpha number -- The interpolation factor.
    @return CFrame -- The starting position with blended rotation.
]=]
function Interpolation.LerpRotation(from: CFrame, to: CFrame, alpha: number): CFrame
	local fromRotation = Facing.GetRotation(from)
	local toRotation = Facing.GetRotation(to)
	local rotation = fromRotation:Lerp(toRotation, alpha)
	return Facing.BuildFromRotation(from.Position, rotation)
end

--[=[
    Interpolates yaw while preserving the current position.
    @within OrientInterpolation
    @param from CFrame -- The starting transform.
    @param to CFrame -- The target transform.
    @param alpha number -- The interpolation factor.
    @return CFrame -- The transform with blended yaw.
]=]
function Interpolation.LerpYaw(from: CFrame, to: CFrame, alpha: number): CFrame
	local fromYaw = Facing.GetYaw(from)
	local toYaw = Facing.GetYaw(to)
	return Facing.SetYaw(from, _LerpAngleRadians(fromYaw, toYaw, alpha))
end

-- Exponential blends
--[=[
    Blends a position toward a target using exponential smoothing.
    @within OrientInterpolation
    @param current Vector3 -- The current position.
    @param target Vector3 -- The target position.
    @param speed number -- The smoothing speed.
    @param dt number -- The elapsed time in seconds.
    @return Vector3 -- The blended position.
]=]
function Interpolation.BlendPosition(current: Vector3, target: Vector3, speed: number, dt: number): Vector3
	return Interpolation.LerpPosition(current, target, _BlendAlpha(speed, dt))
end

--[=[
    Blends a transform toward a target using exponential smoothing.
    @within OrientInterpolation
    @param current CFrame -- The current transform.
    @param target CFrame -- The target transform.
    @param speed number -- The smoothing speed.
    @param dt number -- The elapsed time in seconds.
    @return CFrame -- The blended transform.
]=]
function Interpolation.BlendCFrame(current: CFrame, target: CFrame, speed: number, dt: number): CFrame
	return Interpolation.LerpCFrame(current, target, _BlendAlpha(speed, dt))
end

--[=[
    Blends yaw toward a target transform using exponential smoothing.
    @within OrientInterpolation
    @param current CFrame -- The current transform.
    @param target CFrame -- The target transform.
    @param speed number -- The smoothing speed.
    @param dt number -- The elapsed time in seconds.
    @return CFrame -- The blended transform.
]=]
function Interpolation.BlendYaw(current: CFrame, target: CFrame, speed: number, dt: number): CFrame
	return Interpolation.LerpYaw(current, target, _BlendAlpha(speed, dt))
end

-- Look-at transitions
--[=[
    Blends the current transform toward a look-at target.
    @within OrientInterpolation
    @param current CFrame -- The current transform.
    @param targetPosition Vector3 -- The point to face.
    @param alpha number -- The interpolation factor.
    @return CFrame? -- The blended transform, or `nil` for a degenerate target.
]=]
function Interpolation.LookAtTowards(current: CFrame, targetPosition: Vector3, alpha: number): CFrame?
	local targetFacing = Facing.BuildLookAt(current.Position, targetPosition)
	if targetFacing == nil then
		return nil
	end

	return Interpolation.LerpRotation(current, targetFacing, alpha)
end

--[=[
    Blends the current transform toward a flat look-at target.
    @within OrientInterpolation
    @param current CFrame -- The current transform.
    @param targetPosition Vector3 -- The point to face.
    @param alpha number -- The interpolation factor.
    @return CFrame? -- The blended transform, or `nil` for a degenerate target.
]=]
function Interpolation.FlatLookAtTowards(current: CFrame, targetPosition: Vector3, alpha: number): CFrame?
	local targetFacing = Facing.BuildFlatLookAt(current.Position, targetPosition)
	if targetFacing == nil then
		return nil
	end

	return Interpolation.LerpRotation(current, targetFacing, alpha)
end

return table.freeze(Interpolation)
