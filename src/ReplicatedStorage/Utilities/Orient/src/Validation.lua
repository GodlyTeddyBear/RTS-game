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
--[=[
    Compares two numbers within an epsilon.
    @within OrientValidation
    @param a number -- The first value.
    @param b number -- The second value.
    @param epsilon number -- The tolerance.
    @return boolean -- Whether the numbers are nearly equal.
]=]
function Validation.NearlyEqual(a: number, b: number, epsilon: number): boolean
	return math.abs(a - b) <= epsilon
end

--[=[
    Compares two vectors within an epsilon.
    @within OrientValidation
    @param a Vector3 -- The first vector.
    @param b Vector3 -- The second vector.
    @param epsilon number -- The tolerance.
    @return boolean -- Whether the vectors are nearly equal.
]=]
function Validation.NearlyEqualVector(a: Vector3, b: Vector3, epsilon: number): boolean
	return (a - b).Magnitude <= epsilon
end

--[=[
    Compares two flat vectors within an epsilon.
    @within OrientValidation
    @param a Vector3 -- The first vector.
    @param b Vector3 -- The second vector.
    @param epsilon number -- The tolerance.
    @return boolean -- Whether the flat vectors are nearly equal.
]=]
function Validation.NearlyEqualFlatVector(a: Vector3, b: Vector3, epsilon: number): boolean
	local delta = Vector3.new(a.X - b.X, 0, a.Z - b.Z)
	return delta.Magnitude <= epsilon
end

--[=[
    Compares two transforms within position and angle tolerances.
    @within OrientValidation
    @param a CFrame -- The first transform.
    @param b CFrame -- The second transform.
    @param positionEpsilon number -- The position tolerance.
    @param angleEpsilon number -- The angular tolerance.
    @return boolean -- Whether the transforms are nearly equal.
]=]
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
--[=[
    Checks whether a number is near zero.
    @within OrientValidation
    @param value number -- The value to test.
    @param epsilon number -- The tolerance.
    @return boolean -- Whether the value is near zero.
]=]
function Validation.IsZero(value: number, epsilon: number): boolean
	return math.abs(value) <= epsilon
end

--[=[
    Checks whether a vector is near zero.
    @within OrientValidation
    @param vector Vector3 -- The vector to test.
    @param epsilon number -- The tolerance.
    @return boolean -- Whether the vector is near zero.
]=]
function Validation.IsZeroVector(vector: Vector3, epsilon: number): boolean
	return vector.Magnitude <= epsilon
end

--[=[
    Checks whether a vector is near zero on the XZ plane.
    @within OrientValidation
    @param vector Vector3 -- The vector to test.
    @param epsilon number -- The tolerance.
    @return boolean -- Whether the flat vector is near zero.
]=]
function Validation.IsZeroFlatVector(vector: Vector3, epsilon: number): boolean
	return Vector3.new(vector.X, 0, vector.Z).Magnitude <= epsilon
end

--[=[
    Checks whether two positions are effectively the same.
    @within OrientValidation
    @param fromPosition Vector3 -- The first position.
    @param toPosition Vector3 -- The second position.
    @param epsilon number -- The tolerance.
    @return boolean -- Whether the direction is degenerate.
]=]
function Validation.IsDegenerateDirection(fromPosition: Vector3, toPosition: Vector3, epsilon: number): boolean
	return (toPosition - fromPosition).Magnitude <= epsilon
end

--[=[
    Checks whether two transforms share the same position.
    @within OrientValidation
    @param a CFrame -- The first transform.
    @param b CFrame -- The second transform.
    @param epsilon number -- The tolerance.
    @return boolean -- Whether the positions match.
]=]
function Validation.IsSamePosition(a: CFrame, b: CFrame, epsilon: number): boolean
	return Validation.NearlyEqualVector(a.Position, b.Position, epsilon)
end

--[=[
    Checks whether two transforms share the same yaw.
    @within OrientValidation
    @param a CFrame -- The first transform.
    @param b CFrame -- The second transform.
    @param epsilon number -- The tolerance.
    @return boolean -- Whether the yaw angles match.
]=]
function Validation.IsSameYaw(a: CFrame, b: CFrame, epsilon: number): boolean
	local aYaw = math.atan2(-a.LookVector.X, -a.LookVector.Z)
	local bYaw = math.atan2(-b.LookVector.X, -b.LookVector.Z)
	local delta = math.atan2(math.sin(aYaw - bYaw), math.cos(aYaw - bYaw))
	return math.abs(delta) <= epsilon
end

-- Input assertions
--[=[
    Asserts that a value is positive.
    @within OrientValidation
    @param value number -- The value to check.
    @param label string -- The parameter name used in the error message.
]=]
function Validation.AssertPositive(value: number, label: string)
	assert(value > 0, string.format("Orient %s must be positive", label))
end

--[=[
    Asserts that a value is non-negative.
    @within OrientValidation
    @param value number -- The value to check.
    @param label string -- The parameter name used in the error message.
]=]
function Validation.AssertNonNegative(value: number, label: string)
	assert(value >= 0, string.format("Orient %s must be non-negative", label))
end

--[=[
    Asserts that a count is at least one.
    @within OrientValidation
    @param count number -- The count to check.
    @param label string -- The parameter name used in the error message.
]=]
function Validation.AssertCount(count: number, label: string)
	assert(count >= 1, string.format("Orient %s must be at least 1", label))
end

-- Defaults
--[=[
    Returns the default epsilon used by Orient comparisons.
    @within OrientValidation
    @return number -- The default epsilon.
]=]
function Validation.GetDefaultEpsilon(): number
	return DEFAULT_EPSILON
end

return table.freeze(Validation)
