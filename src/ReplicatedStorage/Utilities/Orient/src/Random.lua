--!strict

local Conversion = require(script.Parent.Conversion)
local Facing = require(script.Parent.Facing)
local Patterns = require(script.Parent.Patterns)
local Validation = require(script.Parent.Validation)

local function _GetRandom(rng: Random?): Random
	-- Default to a fresh RNG when the caller does not supply one.
	return rng or Random.new()
end

local function _RandomAngleRadians(rng: Random): number
	-- Sample a full turn in radians.
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
--[=[
    Samples a random point inside a circle.
    @within OrientRandom
    @param center Vector3 -- The circle center.
    @param radius number -- The maximum radius.
    @param rng Random? -- Optional random generator.
    @return Vector3 -- The sampled point.
]=]
function Random.RandomPointInRadius(center: Vector3, radius: number, rng: Random?): Vector3
	Validation.AssertNonNegative(radius, "radius")
	local random = _GetRandom(rng)
	local angle = _RandomAngleRadians(random)
	local distance = math.sqrt(random:NextNumber()) * radius
	return Patterns.GetPointOnCircle(center, distance, angle)
end

--[=[
    Samples a random point on a circle boundary.
    @within OrientRandom
    @param center Vector3 -- The circle center.
    @param radius number -- The circle radius.
    @param rng Random? -- Optional random generator.
    @return Vector3 -- The sampled point.
]=]
function Random.RandomPointOnRadius(center: Vector3, radius: number, rng: Random?): Vector3
	Validation.AssertNonNegative(radius, "radius")
	return Patterns.GetPointOnCircle(center, radius, _RandomAngleRadians(_GetRandom(rng)))
end

--[=[
    Samples a random point inside an axis-aligned box.
    @within OrientRandom
    @param center Vector3 -- The box center.
    @param size Vector3 -- The box dimensions.
    @param rng Random? -- Optional random generator.
    @return Vector3 -- The sampled point.
]=]
function Random.RandomPointInBox(center: Vector3, size: Vector3, rng: Random?): Vector3
	local random = _GetRandom(rng)
	return Vector3.new(
		center.X + random:NextNumber(-size.X * 0.5, size.X * 0.5),
		center.Y + random:NextNumber(-size.Y * 0.5, size.Y * 0.5),
		center.Z + random:NextNumber(-size.Z * 0.5, size.Z * 0.5)
	)
end

--[=[
    Samples a random point inside axis-aligned bounds.
    @within OrientRandom
    @param minBounds Vector3 -- The minimum corner.
    @param maxBounds Vector3 -- The maximum corner.
    @param rng Random? -- Optional random generator.
    @return Vector3 -- The sampled point.
]=]
function Random.RandomPointInBounds(minBounds: Vector3, maxBounds: Vector3, rng: Random?): Vector3
	local random = _GetRandom(rng)
	return Vector3.new(
		random:NextNumber(minBounds.X, maxBounds.X),
		random:NextNumber(minBounds.Y, maxBounds.Y),
		random:NextNumber(minBounds.Z, maxBounds.Z)
	)
end

--[=[
    Samples a random offset from the origin inside a circle.
    @within OrientRandom
    @param radius number -- The maximum radius.
    @param rng Random? -- Optional random generator.
    @return Vector3 -- The sampled offset.
]=]
function Random.RandomOffset(radius: number, rng: Random?): Vector3
	return Random.RandomPointInRadius(Vector3.zero, radius, rng)
end

--[=[
    Samples a random flat offset from the origin inside a circle.
    @within OrientRandom
    @param radius number -- The maximum radius.
    @param rng Random? -- Optional random generator.
    @return Vector3 -- The sampled offset in the XZ plane.
]=]
function Random.RandomFlatOffset(radius: number, rng: Random?): Vector3
	local point = Random.RandomPointInRadius(Vector3.zero, radius, rng)
	return Vector3.new(point.X, 0, point.Z)
end

-- Random transform generators
--[=[
    Samples a random yaw angle in radians.
    @within OrientRandom
    @param rng Random? -- Optional random generator.
    @return number -- The sampled yaw angle.
]=]
function Random.RandomYaw(rng: Random?): number
	return _RandomAngleRadians(_GetRandom(rng))
end

--[=[
    Samples a random `CFrame` at a position with random yaw.
    @within OrientRandom
    @param position Vector3 -- The position to place the transform.
    @param rng Random? -- Optional random generator.
    @return CFrame -- The sampled transform.
]=]
function Random.RandomYawCFrame(position: Vector3, rng: Random?): CFrame
	return Conversion.FromPositionAndYaw(position, Random.RandomYaw(rng))
end

--[=[
    Replaces the yaw of an existing transform with a random yaw.
    @within OrientRandom
    @param cframe CFrame -- The transform to randomize.
    @param rng Random? -- Optional random generator.
    @return CFrame -- The updated transform.
]=]
function Random.RandomizedYaw(cframe: CFrame, rng: Random?): CFrame
	return Facing.SetYaw(cframe, Random.RandomYaw(rng))
end

--[=[
    Samples a random point on an arc.
    @within OrientRandom
    @param center Vector3 -- The arc center.
    @param radius number -- The arc radius.
    @param startAngleRadians number -- The arc start angle.
    @param endAngleRadians number -- The arc end angle.
    @param rng Random? -- Optional random generator.
    @return Vector3 -- The sampled point.
]=]
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

--[=[
    Samples a random point inside an annulus.
    @within OrientRandom
    @param center Vector3 -- The annulus center.
    @param minRadius number -- The inner radius.
    @param maxRadius number -- The outer radius.
    @param rng Random? -- Optional random generator.
    @return Vector3 -- The sampled point.
]=]
function Random.RandomPointInAnnulus(center: Vector3, minRadius: number, maxRadius: number, rng: Random?): Vector3
	Validation.AssertNonNegative(minRadius, "minRadius")
	Validation.AssertNonNegative(maxRadius, "maxRadius")
	-- The caller expects a valid radius range, not a silent fallback.
	assert(maxRadius >= minRadius, "Orient maxRadius must be greater than or equal to minRadius")
	local random = _GetRandom(rng)
	local radius = math.sqrt(random:NextNumber(minRadius * minRadius, maxRadius * maxRadius))
	return Patterns.GetPointOnCircle(center, radius, _RandomAngleRadians(random))
end

--[=[
    Samples a random point in a front-facing arc.
    @within OrientRandom
    @param origin CFrame -- The reference transform.
    @param minRadius number -- The inner radius.
    @param maxRadius number -- The outer radius.
    @param arcRadians number -- The angular width of the arc.
    @param rng Random? -- Optional random generator.
    @return Vector3 -- The sampled point.
]=]
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

--[=[
    Samples a random transform inside an axis-aligned box.
    @within OrientRandom
    @param center CFrame -- The box center transform.
    @param size Vector3 -- The box dimensions.
    @param randomYaw boolean -- Whether to randomize yaw.
    @param rng Random? -- Optional random generator.
    @return CFrame -- The sampled transform.
]=]
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
