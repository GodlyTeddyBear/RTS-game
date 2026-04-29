--!strict

local Facing = require(script.Parent.Facing)
local Validation = require(script.Parent.Validation)

local function _BlendAlpha(speed: number, dt: number): number
	Validation.AssertNonNegative(speed, "speed")
	Validation.AssertNonNegative(dt, "dt")
	return 1 - math.exp(-speed * dt)
end

local function _LerpAngleRadians(fromAngle: number, toAngle: number, alpha: number): number
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
function Interpolation.LerpPosition(from: Vector3, to: Vector3, alpha: number): Vector3
	return from:Lerp(to, alpha)
end

function Interpolation.LerpCFrame(from: CFrame, to: CFrame, alpha: number): CFrame
	return from:Lerp(to, alpha)
end

function Interpolation.LerpRotation(from: CFrame, to: CFrame, alpha: number): CFrame
	local fromRotation = Facing.GetRotation(from)
	local toRotation = Facing.GetRotation(to)
	local rotation = fromRotation:Lerp(toRotation, alpha)
	return Facing.BuildFromRotation(from.Position, rotation)
end

function Interpolation.LerpYaw(from: CFrame, to: CFrame, alpha: number): CFrame
	local fromYaw = Facing.GetYaw(from)
	local toYaw = Facing.GetYaw(to)
	return Facing.SetYaw(from, _LerpAngleRadians(fromYaw, toYaw, alpha))
end

-- Exponential blends
function Interpolation.BlendPosition(current: Vector3, target: Vector3, speed: number, dt: number): Vector3
	return Interpolation.LerpPosition(current, target, _BlendAlpha(speed, dt))
end

function Interpolation.BlendCFrame(current: CFrame, target: CFrame, speed: number, dt: number): CFrame
	return Interpolation.LerpCFrame(current, target, _BlendAlpha(speed, dt))
end

function Interpolation.BlendYaw(current: CFrame, target: CFrame, speed: number, dt: number): CFrame
	return Interpolation.LerpYaw(current, target, _BlendAlpha(speed, dt))
end

-- Look-at transitions
function Interpolation.LookAtTowards(current: CFrame, targetPosition: Vector3, alpha: number): CFrame?
	local targetFacing = Facing.BuildLookAt(current.Position, targetPosition)
	if targetFacing == nil then
		return nil
	end

	return Interpolation.LerpRotation(current, targetFacing, alpha)
end

function Interpolation.FlatLookAtTowards(current: CFrame, targetPosition: Vector3, alpha: number): CFrame?
	local targetFacing = Facing.BuildFlatLookAt(current.Position, targetPosition)
	if targetFacing == nil then
		return nil
	end

	return Interpolation.LerpRotation(current, targetFacing, alpha)
end

return table.freeze(Interpolation)
