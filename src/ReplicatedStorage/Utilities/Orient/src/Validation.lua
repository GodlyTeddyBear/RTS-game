--!strict

local Constants = require(script.Parent.Constants)

local DEFAULT_EPSILON = Constants.DEFAULT_EPSILON

--[=[
    @class OrientValidation
    Validation, tolerance, and comparison helpers for `Orient`.

    This module centralizes epsilon-based comparisons, zero checks, and input
    assertions so the rest of the package can stay focused on transform math.
    @server
    @client
]=]
local Validation = {}

-- Scalar and vector comparisons
function Validation.NearlyEqual(a: number, b: number, epsilon: number): boolean
	return math.abs(a - b) <= epsilon
end

function Validation.NearlyEqualVector(a: Vector3, b: Vector3, epsilon: number): boolean
	return (a - b).Magnitude <= epsilon
end

function Validation.NearlyEqualFlatVector(a: Vector3, b: Vector3, epsilon: number): boolean
	local delta = Vector3.new(a.X - b.X, 0, a.Z - b.Z)
	return delta.Magnitude <= epsilon
end

function Validation.NearlyEqualCFrame(
	a: CFrame,
	b: CFrame,
	positionEpsilon: number,
	angleEpsilon: number
): boolean
	if not Validation.NearlyEqualVector(a.Position, b.Position, positionEpsilon) then
		return false
	end

	local lookDot = math.clamp(a.LookVector:Dot(b.LookVector), -1, 1)
	local upDot = math.clamp(a.UpVector:Dot(b.UpVector), -1, 1)
	local lookAngle = math.acos(lookDot)
	local upAngle = math.acos(upDot)
	return lookAngle <= angleEpsilon and upAngle <= angleEpsilon
end

-- Zero checks
function Validation.IsZero(value: number, epsilon: number): boolean
	return math.abs(value) <= epsilon
end

function Validation.IsZeroVector(vector: Vector3, epsilon: number): boolean
	return vector.Magnitude <= epsilon
end

function Validation.IsZeroFlatVector(vector: Vector3, epsilon: number): boolean
	return Vector3.new(vector.X, 0, vector.Z).Magnitude <= epsilon
end

function Validation.IsDegenerateDirection(fromPosition: Vector3, toPosition: Vector3, epsilon: number): boolean
	return (toPosition - fromPosition).Magnitude <= epsilon
end

function Validation.IsSamePosition(a: CFrame, b: CFrame, epsilon: number): boolean
	return Validation.NearlyEqualVector(a.Position, b.Position, epsilon)
end

function Validation.IsSameYaw(a: CFrame, b: CFrame, epsilon: number): boolean
	local aYaw = math.atan2(-a.LookVector.X, -a.LookVector.Z)
	local bYaw = math.atan2(-b.LookVector.X, -b.LookVector.Z)
	local delta = math.atan2(math.sin(aYaw - bYaw), math.cos(aYaw - bYaw))
	return math.abs(delta) <= epsilon
end

-- Input assertions
function Validation.AssertPositive(value: number, label: string)
	assert(value > 0, string.format("Orient %s must be positive", label))
end

function Validation.AssertNonNegative(value: number, label: string)
	assert(value >= 0, string.format("Orient %s must be non-negative", label))
end

function Validation.AssertCount(count: number, label: string)
	assert(count >= 1, string.format("Orient %s must be at least 1", label))
end

-- Defaults
function Validation.GetDefaultEpsilon(): number
	return DEFAULT_EPSILON
end

return table.freeze(Validation)
