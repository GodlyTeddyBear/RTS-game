--!strict

local Conversion = require(script.Parent.Conversion)
local Facing = require(script.Parent.Facing)
local Patterns = require(script.Parent.Patterns)
local Validation = require(script.Parent.Validation)

local function _GetRandom(rng: Random?): Random
	return rng or Random.new()
end

local function _RandomAngleRadians(rng: Random): number
	return rng:NextNumber(0, math.pi * 2)
end

--[=[
    @class OrientRandom
    Randomized transform generation helpers for `Orient`.

    This module samples points, offsets, yaws, and transforms from common
    geometric shapes using an optional caller-provided `Random` object.
    @server
    @client
]=]
local Random = {}

-- Random point generators
function Random.RandomPointInRadius(center: Vector3, radius: number, rng: Random?): Vector3
	Validation.AssertNonNegative(radius, "radius")
	local random = _GetRandom(rng)
	local angle = _RandomAngleRadians(random)
	local distance = math.sqrt(random:NextNumber()) * radius
	return Patterns.GetPointOnCircle(center, distance, angle)
end

function Random.RandomPointOnRadius(center: Vector3, radius: number, rng: Random?): Vector3
	Validation.AssertNonNegative(radius, "radius")
	return Patterns.GetPointOnCircle(center, radius, _RandomAngleRadians(_GetRandom(rng)))
end

function Random.RandomPointInBox(center: Vector3, size: Vector3, rng: Random?): Vector3
	local random = _GetRandom(rng)
	return Vector3.new(
		center.X + random:NextNumber(-size.X * 0.5, size.X * 0.5),
		center.Y + random:NextNumber(-size.Y * 0.5, size.Y * 0.5),
		center.Z + random:NextNumber(-size.Z * 0.5, size.Z * 0.5)
	)
end

function Random.RandomPointInBounds(minBounds: Vector3, maxBounds: Vector3, rng: Random?): Vector3
	local random = _GetRandom(rng)
	return Vector3.new(
		random:NextNumber(minBounds.X, maxBounds.X),
		random:NextNumber(minBounds.Y, maxBounds.Y),
		random:NextNumber(minBounds.Z, maxBounds.Z)
	)
end

function Random.RandomOffset(radius: number, rng: Random?): Vector3
	return Random.RandomPointInRadius(Vector3.zero, radius, rng)
end

function Random.RandomFlatOffset(radius: number, rng: Random?): Vector3
	local point = Random.RandomPointInRadius(Vector3.zero, radius, rng)
	return Vector3.new(point.X, 0, point.Z)
end

-- Random transform generators
function Random.RandomYaw(rng: Random?): number
	return _RandomAngleRadians(_GetRandom(rng))
end

function Random.RandomYawCFrame(position: Vector3, rng: Random?): CFrame
	return Conversion.FromPositionAndYaw(position, Random.RandomYaw(rng))
end

function Random.RandomizedYaw(cframe: CFrame, rng: Random?): CFrame
	return Facing.SetYaw(cframe, Random.RandomYaw(rng))
end

function Random.RandomPointOnArc(
	center: Vector3,
	radius: number,
	startAngleRadians: number,
	endAngleRadians: number,
	rng: Random?
): Vector3
	local random = _GetRandom(rng)
	return Patterns.GetPointOnCircle(center, radius, random:NextNumber(startAngleRadians, endAngleRadians))
end

function Random.RandomPointInAnnulus(center: Vector3, minRadius: number, maxRadius: number, rng: Random?): Vector3
	Validation.AssertNonNegative(minRadius, "minRadius")
	Validation.AssertNonNegative(maxRadius, "maxRadius")
	assert(maxRadius >= minRadius, "Orient maxRadius must be greater than or equal to minRadius")
	local random = _GetRandom(rng)
	local radius = math.sqrt(random:NextNumber(minRadius * minRadius, maxRadius * maxRadius))
	return Patterns.GetPointOnCircle(center, radius, _RandomAngleRadians(random))
end

function Random.RandomPointInFrontArc(
	origin: CFrame,
	minRadius: number,
	maxRadius: number,
	arcRadians: number,
	rng: Random?
): Vector3
	local random = _GetRandom(rng)
	local radius = math.sqrt(random:NextNumber(minRadius * minRadius, maxRadius * maxRadius))
	local localAngle = random:NextNumber(-arcRadians * 0.5, arcRadians * 0.5)
	local localOffset = Vector3.new(math.sin(localAngle) * radius, 0, -math.cos(localAngle) * radius)
	return origin:PointToWorldSpace(localOffset)
end

function Random.RandomTransformInBox(center: CFrame, size: Vector3, randomYaw: boolean, rng: Random?): CFrame
	local random = _GetRandom(rng)
	local localOffset = Vector3.new(
		random:NextNumber(-size.X * 0.5, size.X * 0.5),
		random:NextNumber(-size.Y * 0.5, size.Y * 0.5),
		random:NextNumber(-size.Z * 0.5, size.Z * 0.5)
	)
	local position = center:PointToWorldSpace(localOffset)
	if not randomYaw then
		return Conversion.WithRotation(position, center)
	end

	return Conversion.FromPositionAndYaw(position, Random.RandomYaw(random))
end

return table.freeze(Random)
