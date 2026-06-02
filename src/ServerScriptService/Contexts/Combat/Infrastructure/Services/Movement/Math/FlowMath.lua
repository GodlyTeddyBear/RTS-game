--!strict
--!optimize 2
--!native

local MovementMath = require(script.Parent.MovementMath)

local FlowMath = {}

local LOOKAHEAD_SECONDS = 1
local MIN_LOOKAHEAD_STUDS = 12
local MOVE_DIRECTION_EPSILON = 0.05
local DEFAULT_ARRIVAL_RADIUS = 1.5

function FlowMath.ResolveArrivalRadius(goalPosition: Vector3, goalWorldSample: Vector3): number
	local sampleOffset = (goalWorldSample - goalPosition).Magnitude
	return math.max(DEFAULT_ARRIVAL_RADIUS, sampleOffset + 0.5)
end

function FlowMath.ResolveLookaheadDistanceStuds(walkSpeed: number, cellWidthStuds: number?): number
	local cellWidth = (type(cellWidthStuds) == "number") and cellWidthStuds or 0
	return math.max(MIN_LOOKAHEAD_STUDS, walkSpeed * LOOKAHEAD_SECONDS, cellWidth * 0.5)
end

function FlowMath.BlendVelocity(
	flowXZ: Vector2,
	separationXZ: Vector2,
	previousVelocityXZ: Vector2,
	walkSpeed: number,
	velAlpha: number
): Vector2
	if walkSpeed <= 0 then
		return Vector2.zero
	end

	local unclampedVelocity = flowXZ + separationXZ
	local targetVelocity = MovementMath.ClampVector2Magnitude(unclampedVelocity, walkSpeed)
	return previousVelocityXZ * (1 - velAlpha) + targetVelocity * velAlpha
end

function FlowMath.ComputeMoveTarget(currentPosition: Vector3, velocityXZ: Vector2, lookaheadDistance: number): Vector3?
	local magnitude = velocityXZ.Magnitude
	if magnitude <= MOVE_DIRECTION_EPSILON then
		return nil
	end

	local scale = lookaheadDistance / magnitude
	return Vector3.new(
		currentPosition.X + velocityXZ.X * scale,
		currentPosition.Y,
		currentPosition.Z + velocityXZ.Y * scale
	)
end

return table.freeze(FlowMath)
