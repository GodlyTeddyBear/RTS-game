--!strict

--[=[
	@class BoidsHelper
	Shared boids-style steering sessions for combat movement.

	Tracks per-session entity state, computes flattened steering on the ground
	plane, and reports arrival back to the movement service.
	@server
]=]

-- ── Types ───────────────────────────────────────────────────────────────────

--[=[
	@interface TBoidsConfig
	@within BoidsHelper
	Shared tuning values for separation, cohesion, target seeking, and arrival.
	.SeparationRadius number
	.NeighborRadius number
	.SeparationWeight number
	.CohesionWeight number
	.AlignmentWeight number
	.TargetWeight number
	.MaxSpeed number
	.MinSpeed number
	.MaxForce number
	.Smoothing number
	.ArrivalThreshold number
	.MinGroupSize number?
]=]
export type TBoidsConfig = {
	SeparationRadius: number,
	NeighborRadius: number,
	SeparationWeight: number,
	CohesionWeight: number,
	AlignmentWeight: number,
	TargetWeight: number,
	MaxSpeed: number,
	MinSpeed: number,
	MaxForce: number,
	Smoothing: number,
	ArrivalThreshold: number,
	MinGroupSize: number?,
	WaypointArrivalThreshold: number?,
	PathRecomputeGoalDelta: number?,
	PathRecomputeCooldownSeconds: number?,
	SeparationMinDistanceEpsilon: number?,
	CorridorLaneOffsetStuds: number?,
	GoalSlotRingRadius: number?,
	MinForwardAlongProgress: number?,
	JumpWaypointArrivalThreshold: number?,
	JumpWhenStuckEnabled: boolean?,
	JumpStuckEpsilonStuds: number?,
	JumpStuckMinTicks: number?,
	JumpUseMoveTo: boolean?,
	JumpMoveToTimeoutSeconds: number?,
	SeparationFalloffExponent: number?,
	SeparationLateralRawCap: number?,
	OrbitEscapeEnabled: boolean?,
	OrbitEscapeMinTicks: number?,
	OrbitEscapeAlongThreshold: number?,
	OrbitEscapeLateralThreshold: number?,
	OrbitEscapeBiasScale: number?,
}

--[=[
	@interface TBoidsOptions
	@within BoidsHelper
	.Config TBoidsConfig
	.GetPosition function -- Resolves the current world position for an entity.
]=]
export type TBoidsOptions = {
	Config: TBoidsConfig,
	GetPosition: (entity: any) -> Vector3?,
	GetGoalPosition: ((entity: any) -> Vector3?)?,
	ComputePathWaypoints: ((entity: any, targetPosition: Vector3) -> (boolean, { any }?, string?))?,
}

type TEntityState = {
	Velocity: Vector3,
	Position: Vector3,
	Waypoints: { any }?,
	WaypointIndex: number,
	LastPathTarget: Vector3,
	LastPathComputeTime: number,
	LastJumpWaypointIndex: number,
	CorridorLaneSerial: number,
	JumpStuckLastSamplePosition: Vector3?,
	JumpStuckLowMotionTicks: number,
	JumpMoveToInFlightWaypointIndex: number,
	OrbitEscapeLowProgressTicks: number,
}

type TSession = {
	SessionId: string,
	TargetPosition: Vector3,
	Entities: { [any]: TEntityState },
	EntityCount: number,
	NextCorridorLaneSerial: number,
}

-- ── Private ────────────────────────────────────────────────────────────────

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Orient = require(ReplicatedStorage.Utilities.Orient)

local BoidsHelper = {}

local sessions: { [string]: TSession } = {}
local MIN_WAYPOINT_COUNT = 2

-- Flatten movement to XZ so the helper stays on the ground plane.
local function flatten(vector: Vector3): Vector3
	return Vector3.new(vector.X, 0, vector.Z)
end

-- Clamp a steering vector so one tick cannot overdrive the caller's movement.
local function clampMagnitude(vector: Vector3, maxMagnitude: number): Vector3
	if vector.Magnitude > maxMagnitude then
		return vector.Unit * maxMagnitude
	end

	return vector
end

-- Path tangent must resolve a non-zero XZ segment; progress bias uses steeringTarget direction.
local PATH_TANGENT_MIN_LENGTH = 0.01
local PROGRESS_DIRECTION_MIN_LENGTH = 0.05

local function steerFromDesired(config: TBoidsConfig, desired: Vector3, previousVelocity: Vector3): Vector3
	local flatDesired = flatten(desired)
	if flatDesired.Magnitude <= 0 then
		return Vector3.zero
	end

	local targetVelocity = flatDesired.Unit * config.MaxSpeed
	return clampMagnitude(targetVelocity - previousVelocity, config.MaxForce)
end

local function getWaypointArrivalThreshold(config: TBoidsConfig): number
	local configuredThreshold = config.WaypointArrivalThreshold
	if type(configuredThreshold) ~= "number" then
		return config.ArrivalThreshold
	end
	return math.max(0, configuredThreshold)
end

local function getJumpWaypointArrivalThreshold(config: TBoidsConfig): number
	local configured = config.JumpWaypointArrivalThreshold
	if type(configured) == "number" and configured > 0 then
		return configured
	end
	return getWaypointArrivalThreshold(config)
end

local function getWaypointConsumeThreshold(config: TBoidsConfig, action: Enum.PathWaypointAction?): number
	if action == Enum.PathWaypointAction.Jump then
		return getJumpWaypointArrivalThreshold(config)
	end
	return getWaypointArrivalThreshold(config)
end

local function updateJumpStuckWatchdog(
	config: TBoidsConfig,
	entityState: TEntityState,
	boidPosition: Vector3,
	activeWaypoint: any?
): boolean
	if activeWaypoint == nil or activeWaypoint.Action ~= Enum.PathWaypointAction.Jump then
		entityState.JumpStuckLowMotionTicks = 0
		entityState.JumpStuckLastSamplePosition = nil
		return false
	end

	if config.JumpWhenStuckEnabled == false then
		return false
	end

	local epsilon = config.JumpStuckEpsilonStuds
	if type(epsilon) ~= "number" or epsilon <= 0 then
		epsilon = 0.15
	end

	local minTicks = config.JumpStuckMinTicks
	if type(minTicks) ~= "number" or minTicks < 1 then
		minTicks = 3
	end

	local lastSample = entityState.JumpStuckLastSamplePosition
	if lastSample == nil then
		entityState.JumpStuckLastSamplePosition = boidPosition
		entityState.JumpStuckLowMotionTicks = 0
		return false
	end

	local delta = flatten(boidPosition - lastSample).Magnitude
	if delta < epsilon then
		entityState.JumpStuckLowMotionTicks += 1
		if entityState.JumpStuckLowMotionTicks >= minTicks then
			entityState.JumpStuckLowMotionTicks = 0
			entityState.JumpStuckLastSamplePosition = boidPosition
			return true
		end
	else
		entityState.JumpStuckLowMotionTicks = 0
		entityState.JumpStuckLastSamplePosition = boidPosition
	end

	return false
end

local function getPathRecomputeGoalDelta(config: TBoidsConfig): number
	local configuredDelta = config.PathRecomputeGoalDelta
	if type(configuredDelta) ~= "number" then
		return config.ArrivalThreshold
	end
	return math.max(0, configuredDelta)
end

local function getPathRecomputeCooldown(config: TBoidsConfig): number
	local configuredCooldown = config.PathRecomputeCooldownSeconds
	if type(configuredCooldown) ~= "number" then
		return 0.5
	end
	return math.max(0, configuredCooldown)
end

local function getSeparationMinDistanceEpsilon(config: TBoidsConfig): number
	local configured = config.SeparationMinDistanceEpsilon
	if type(configured) == "number" and configured > 0 then
		return configured
	end
	return 0.08
end

local function getSeparationFalloffExponent(config: TBoidsConfig): number
	local exponent = config.SeparationFalloffExponent
	if type(exponent) ~= "number" or exponent <= 0 then
		return 0
	end
	return exponent
end

local function getCorridorLaneOffsetStuds(config: TBoidsConfig): number
	local configured = config.CorridorLaneOffsetStuds
	if type(configured) == "number" and configured > 0 then
		return configured
	end
	return 0
end

local function getGoalSlotRingRadius(config: TBoidsConfig): number
	local configured = config.GoalSlotRingRadius
	if type(configured) == "number" and configured > 0 then
		return configured
	end
	return 0
end

local function getMinForwardAlongProgress(config: TBoidsConfig): number
	local configured = config.MinForwardAlongProgress
	if type(configured) == "number" and configured > 0 then
		return configured
	end
	return 0
end

local function applyMinForwardAlongProgress(
	config: TBoidsConfig,
	progressForwardUnit: Vector3?,
	smoothed: Vector3
): Vector3
	local minAlong = getMinForwardAlongProgress(config)
	if minAlong <= 0 then
		return smoothed
	end

	if progressForwardUnit == nil then
		return smoothed
	end

	local fu = flatten(progressForwardUnit)
	if fu.Magnitude < 0.01 then
		return smoothed
	end

	local forwardUnit = fu.Unit
	local flat = flatten(smoothed)
	local along = flat:Dot(forwardUnit)
	if along >= minAlong then
		return smoothed
	end

	flat = flat + forwardUnit * (minAlong - along)
	return clampMagnitude(flat, config.MaxSpeed)
end

-- Nudge steering forward when agents churn laterally with little path progress (mitigates separation orbit loops).
local function applyOrbitEscapeBias(
	config: TBoidsConfig,
	entityState: TEntityState,
	pathProgressForwardUnit: Vector3?,
	smoothed: Vector3
): Vector3
	if pathProgressForwardUnit == nil then
		entityState.OrbitEscapeLowProgressTicks = 0
		return smoothed
	end

	if config.OrbitEscapeEnabled == false then
		entityState.OrbitEscapeLowProgressTicks = 0
		return smoothed
	end

	local fu = flatten(pathProgressForwardUnit)
	if fu.Magnitude < 0.01 then
		entityState.OrbitEscapeLowProgressTicks = 0
		return smoothed
	end

	local forwardUnit = fu.Unit
	local flat = flatten(smoothed)
	local along = flat:Dot(forwardUnit)
	local lateral = flat - along * forwardUnit
	local alongTh = config.OrbitEscapeAlongThreshold
	if type(alongTh) ~= "number" then
		alongTh = 0.1
	end
	local latTh = config.OrbitEscapeLateralThreshold
	if type(latTh) ~= "number" then
		latTh = 0.12
	end

	if math.abs(along) < alongTh and lateral.Magnitude > latTh then
		local minTicks = config.OrbitEscapeMinTicks
		if type(minTicks) ~= "number" or minTicks < 1 then
			minTicks = 4
		end
		entityState.OrbitEscapeLowProgressTicks += 1
		if entityState.OrbitEscapeLowProgressTicks >= minTicks then
			entityState.OrbitEscapeLowProgressTicks = 0
			local biasScale = config.OrbitEscapeBiasScale
			if type(biasScale) ~= "number" or biasScale <= 0 then
				biasScale = 0.35
			end
			flat = flat + forwardUnit * (config.MaxSpeed * biasScale)
			return clampMagnitude(flat, config.MaxSpeed)
		end
	else
		entityState.OrbitEscapeLowProgressTicks = 0
	end

	return smoothed
end

local GOLDEN_ANGLE_RAD = 2.399963229728653

local function corridorLaneLateralScale(corridorLaneSerial: number): number
	return math.sin(corridorLaneSerial * GOLDEN_ANGLE_RAD)
end

local function hashStringSeed(parts: { string }): number
	local seed = 5381
	for _, part in parts do
		for i = 1, #part do
			seed = (seed * 33 + string.byte(part, i)) % 2147483647
		end
	end
	return seed
end

local function goalSlotOffsetFromEntity(entity: any, radius: number): Vector3
	if radius <= 0 then
		return Vector3.zero
	end
	local seed: number
	if type(entity) == "number" then
		seed = (entity * 2246822519) % 2147483647
	else
		seed = hashStringSeed({ tostring(entity) })
	end
	local angle = (seed % 10000) / 10000 * 2 * math.pi
	return Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
end

local function computeArrivalPosition(entity: any, strategicGoal: Vector3, config: TBoidsConfig): Vector3
	return strategicGoal + goalSlotOffsetFromEntity(entity, getGoalSlotRingRadius(config))
end

local function xzPerpendicularRight(tangentUnit: Vector3): Vector3
	local flat = flatten(tangentUnit)
	if flat.Magnitude < 0.01 then
		return Vector3.new(1, 0, 0)
	end
	local u = flat.Unit
	return Vector3.new(-u.Z, 0, u.X)
end

local function xzPathTangentStable(
	waypoints: { any },
	waypointIndex: number,
	strategicGoal: Vector3,
	activeWaypointPosition: Vector3
): (Vector3, boolean)
	local nextWp = waypoints[waypointIndex + 1]
	if nextWp ~= nil then
		local toNext = flatten(nextWp.Position - activeWaypointPosition)
		if toNext.Magnitude >= PATH_TANGENT_MIN_LENGTH then
			return toNext.Unit, true
		end
	end

	local toGoalFromWp = flatten(strategicGoal - activeWaypointPosition)
	if toGoalFromWp.Magnitude >= PATH_TANGENT_MIN_LENGTH then
		return toGoalFromWp.Unit, true
	end

	if waypointIndex >= 2 then
		local prevWp = waypoints[waypointIndex - 1]
		if prevWp ~= nil then
			local inbound = flatten(activeWaypointPosition - prevWp.Position)
			if inbound.Magnitude >= PATH_TANGENT_MIN_LENGTH then
				return inbound.Unit, true
			end
		end
	end

	for wi = waypointIndex - 1, 2, -1 do
		local prev = waypoints[wi - 1]
		local cur = waypoints[wi]
		if prev ~= nil and cur ~= nil then
			local leg = flatten(cur.Position - prev.Position)
			if leg.Magnitude >= PATH_TANGENT_MIN_LENGTH then
				return leg.Unit, true
			end
		end
	end

	return Vector3.new(1, 0, 0), false
end

-- Forward axis for path progress: toward active waypoint, else stable polyline tangent (not lane-offset seek).
local function resolvePathProgressForwardUnit(
	boidPosition: Vector3,
	activeWaypointPosition: Vector3,
	waypoints: { any }?,
	waypointIndex: number,
	strategicGoal: Vector3
): Vector3?
	local toWaypoint = flatten(activeWaypointPosition - boidPosition)
	if toWaypoint.Magnitude >= PROGRESS_DIRECTION_MIN_LENGTH then
		return toWaypoint.Unit
	end

	if waypoints ~= nil then
		local tangent, tangentOk = xzPathTangentStable(waypoints, waypointIndex, strategicGoal, activeWaypointPosition)
		if tangentOk then
			return tangent
		end
	end

	return nil
end

local function corridorSteeringTarget(
	waypoints: { any },
	waypointIndex: number,
	activeWaypointPosition: Vector3,
	strategicGoal: Vector3,
	corridorLaneSerial: number,
	config: TBoidsConfig
): Vector3
	local laneStuds = getCorridorLaneOffsetStuds(config)
	if laneStuds <= 0 then
		return activeWaypointPosition
	end

	local tangent, tangentOk = xzPathTangentStable(waypoints, waypointIndex, strategicGoal, activeWaypointPosition)
	if not tangentOk then
		return activeWaypointPosition
	end

	local right = xzPerpendicularRight(tangent)
	local lateralScale = corridorLaneLateralScale(corridorLaneSerial)
	return activeWaypointPosition + right * (lateralScale * laneStuds)
end

local function computeLockOnFlatForward(
	boidPosition: Vector3,
	steeringTarget: Vector3,
	activeWaypointPosition: Vector3,
	waypoints: { any }?,
	waypointIndex: number,
	goalPosition: Vector3,
	pathProgressForwardUnit: Vector3?
): Vector3?
	if waypoints ~= nil then
		local tangent, tangentOk = xzPathTangentStable(waypoints, waypointIndex, goalPosition, activeWaypointPosition)
		if tangentOk then
			return tangent
		end
	end

	if pathProgressForwardUnit ~= nil then
		return pathProgressForwardUnit
	end

	return Orient.SafeUnit(flatten(steeringTarget - boidPosition))
end

local function seek(
	config: TBoidsConfig,
	boidPosition: Vector3,
	targetPosition: Vector3,
	previousVelocity: Vector3
): Vector3
	return steerFromDesired(config, flatten(targetPosition - boidPosition), previousVelocity)
end

-- Resolve the caller-provided position accessor and tolerate missing callbacks.
local function getEntityPosition(entity: any, options: TBoidsOptions): Vector3?
	if type(options.GetPosition) ~= "function" then
		return nil
	end

	return options.GetPosition(entity)
end

local function getGoalPosition(entity: any, session: TSession, options: TBoidsOptions): Vector3
	if type(options.GetGoalPosition) ~= "function" then
		return session.TargetPosition
	end

	local resolvedGoalPosition = options.GetGoalPosition(entity)
	if typeof(resolvedGoalPosition) == "Vector3" then
		session.TargetPosition = resolvedGoalPosition
	end

	return session.TargetPosition
end

local function resolveWaypointStartIndex(waypoints: { any }): number
	for waypointIndex = 2, #waypoints do
		local currentWaypoint = waypoints[waypointIndex]
		local previousWaypoint = waypoints[waypointIndex - 1]
		if currentWaypoint ~= nil and previousWaypoint ~= nil then
			if (currentWaypoint.Position - previousWaypoint.Position).Magnitude > 0.1 then
				return waypointIndex
			end
		end
	end

	return 2
end

local function computePathWaypoints(entity: any, targetPosition: Vector3, options: TBoidsOptions): { any }?
	if type(options.ComputePathWaypoints) ~= "function" then
		return nil
	end

	local success, waypoints = options.ComputePathWaypoints(entity, targetPosition)
	if success ~= true or waypoints == nil or type(waypoints) ~= "table" then
		return nil
	end
	if #waypoints < MIN_WAYPOINT_COUNT then
		return nil
	end

	return waypoints
end

local function createSession(sessionId: string, targetPosition: Vector3): TSession
	local session = {
		SessionId = sessionId,
		TargetPosition = targetPosition,
		Entities = {},
		EntityCount = 0,
		NextCorridorLaneSerial = 0,
	}
	sessions[sessionId] = session
	return session
end

-- Register an entity once and seed its tracked velocity and position.
local function registerEntity(
	session: TSession,
	entity: any,
	position: Vector3,
	targetPosition: Vector3,
	waypoints: { any }
)
	local prior = session.Entities[entity]
	local corridorLaneSerial: number
	if prior ~= nil then
		corridorLaneSerial = prior.CorridorLaneSerial
	else
		corridorLaneSerial = session.NextCorridorLaneSerial
		session.NextCorridorLaneSerial += 1
	end

	if not session.Entities[entity] then
		session.EntityCount += 1
	end

	session.Entities[entity] = {
		Velocity = Vector3.zero,
		Position = position,
		Waypoints = waypoints,
		WaypointIndex = resolveWaypointStartIndex(waypoints),
		LastPathTarget = targetPosition,
		LastPathComputeTime = os.clock(),
		LastJumpWaypointIndex = 0,
		CorridorLaneSerial = corridorLaneSerial,
		JumpStuckLastSamplePosition = nil,
		JumpStuckLowMotionTicks = 0,
		JumpMoveToInFlightWaypointIndex = 0,
		OrbitEscapeLowProgressTicks = 0,
	}
end

local function updateEntityPosition(session: TSession, entity: any, position: Vector3, velocity: Vector3)
	local state = session.Entities[entity]
	if not state then
		return
	end

	state.Position = position
	state.Velocity = velocity
end

local function pairSeparationRaw(
	entity: any,
	otherEntity: any,
	epsilon: number,
	boidPosition: Vector3,
	otherPosition: Vector3,
	separationRadius: number
): Vector3?
	local offset = flatten(boidPosition - otherPosition)
	local distance = offset.Magnitude
	if distance >= separationRadius then
		return nil
	end

	if distance >= epsilon then
		return offset.Unit / distance
	end

	local seed = hashStringSeed({ tostring(entity), "|", tostring(otherEntity) })
	local angle = (seed % 10000) / 10000 * 2 * math.pi
	return Vector3.new(math.cos(angle), 0, math.sin(angle)) / epsilon
end

-- Calculate the separation force by repelling the entity from close neighbors.
-- When progressForwardUnit is set, repulsion is projected onto the XZ plane perpendicular to it
-- so separation does not pull the agent away from the steering target.
local function calculateSeparation(
	config: TBoidsConfig,
	entity: any,
	session: TSession,
	boidPosition: Vector3,
	previousVelocity: Vector3,
	options: TBoidsOptions,
	progressForwardUnit: Vector3?
): Vector3
	local epsilon = getSeparationMinDistanceEpsilon(config)
	local rawSum = Vector3.zero
	local count = 0

	for otherEntity, state in session.Entities do
		if otherEntity == entity then
			continue
		end

		local otherPosition = getEntityPosition(otherEntity, options) or state.Position
		local distance = flatten(boidPosition - otherPosition).Magnitude
		if distance >= config.SeparationRadius then
			continue
		end

		local raw = pairSeparationRaw(entity, otherEntity, epsilon, boidPosition, otherPosition, config.SeparationRadius)
		if raw ~= nil then
			local falloffExponent = getSeparationFalloffExponent(config)
			if falloffExponent > 0 and config.SeparationRadius > 1e-6 then
				local edgeT = math.clamp(1 - distance / config.SeparationRadius, 0, 1)
				raw *= edgeT ^ falloffExponent
			end
			rawSum += raw
			count += 1
		end
	end

	if count == 0 then
		return Vector3.zero
	end

	local rawAvg = flatten(rawSum / count)

	if progressForwardUnit ~= nil then
		local fu = flatten(progressForwardUnit)
		if fu.Magnitude >= 0.01 then
			local u = fu.Unit
			rawAvg -= rawAvg:Dot(u) * u
		end
	end

	if rawAvg.Magnitude < 1e-8 then
		return Vector3.zero
	end

	local lateralCap = config.SeparationLateralRawCap
	if type(lateralCap) == "number" and lateralCap > 0 and rawAvg.Magnitude > lateralCap then
		rawAvg = rawAvg.Unit * lateralCap
	end

	return steerFromDesired(config, rawAvg, previousVelocity)
end

-- Calculate the alignment force from nearby heading averages.
local function calculateAlignment(
	config: TBoidsConfig,
	entity: any,
	session: TSession,
	boidPosition: Vector3,
	previousVelocity: Vector3
): Vector3
	local velocitySum = Vector3.zero
	local count = 0

	for otherEntity, state in session.Entities do
		-- Ignore self so the entity only aligns with neighbors.
		if otherEntity == entity then
			continue
		end

		local offset = flatten(boidPosition - state.Position)
		local distance = offset.Magnitude
		-- Only close entities should influence the shared heading.
		if distance > 0 and distance < config.NeighborRadius then
			velocitySum += state.Velocity
			count += 1
		end
	end

	if count == 0 then
		return Vector3.zero
	end

	return steerFromDesired(config, velocitySum / count, previousVelocity)
end

-- Calculate the cohesion force toward the local center of mass.
local function calculateCohesion(
	config: TBoidsConfig,
	entity: any,
	session: TSession,
	boidPosition: Vector3,
	previousVelocity: Vector3
): Vector3
	local positionSum = Vector3.zero
	local count = 0

	for otherEntity, state in session.Entities do
		-- Ignore self so the entity does not bias its own center point.
		if otherEntity == entity then
			continue
		end

		local offset = flatten(boidPosition - state.Position)
		local distance = offset.Magnitude
		-- Only nearby entities should pull the group center toward them.
		if distance > 0 and distance < config.NeighborRadius then
			positionSum += state.Position
			count += 1
		end
	end

	if count == 0 then
		return Vector3.zero
	end

	return seek(config, boidPosition, positionSum / count, previousVelocity)
end

-- Blend all boids forces into one flattened steering vector.
local function calculateBoidsForce(
	config: TBoidsConfig,
	entity: any,
	session: TSession,
	boidPosition: Vector3,
	previousVelocity: Vector3,
	steeringTarget: Vector3,
	options: TBoidsOptions,
	pathProgressForwardUnit: Vector3?
): Vector3
	-- Resolve each influence separately so the weights stay easy to tune.
	local separation =
		calculateSeparation(config, entity, session, boidPosition, previousVelocity, options, pathProgressForwardUnit)
	local alignment = calculateAlignment(config, entity, session, boidPosition, previousVelocity)
	local cohesion = calculateCohesion(config, entity, session, boidPosition, previousVelocity)
	local target = seek(config, boidPosition, steeringTarget, previousVelocity)

	-- Combine the weighted forces before smoothing and clamping.
	local combined = separation * config.SeparationWeight
		+ alignment * config.AlignmentWeight
		+ cohesion * config.CohesionWeight
		+ target * config.TargetWeight

	-- Cap the force and dampen jitter so movement changes stay stable frame to frame.
	local clamped = clampMagnitude(flatten(combined), config.MaxSpeed)
	local smoothed = previousVelocity:Lerp(clamped, config.Smoothing)
	smoothed = applyMinForwardAlongProgress(config, pathProgressForwardUnit, smoothed)

	local entityState = session.Entities[entity]
	if entityState ~= nil then
		smoothed = applyOrbitEscapeBias(config, entityState, pathProgressForwardUnit, smoothed)
	end

	-- Treat tiny residual motion as idle so callers can stop moving the humanoid.
	if smoothed.Magnitude < config.MinSpeed then
		return Vector3.zero
	end

	return smoothed
end

local function recomputePathIfNeeded(
	config: TBoidsConfig,
	entity: any,
	state: TEntityState,
	targetPosition: Vector3,
	options: TBoidsOptions,
	forceRecompute: boolean
): boolean
	local now = os.clock()
	if not forceRecompute then
		if now - state.LastPathComputeTime < getPathRecomputeCooldown(config) then
			return false
		end
		local targetDelta = flatten(targetPosition - state.LastPathTarget).Magnitude
		if targetDelta < getPathRecomputeGoalDelta(config) and state.Waypoints ~= nil and state.WaypointIndex <= #state.Waypoints then
			return false
		end
	end

	local recomputedWaypoints = computePathWaypoints(entity, targetPosition, options)
	if recomputedWaypoints == nil then
		return false
	end

	state.Waypoints = recomputedWaypoints
	state.WaypointIndex = resolveWaypointStartIndex(recomputedWaypoints)
	state.LastPathTarget = targetPosition
	state.LastPathComputeTime = now
	state.LastJumpWaypointIndex = 0
	state.JumpStuckLastSamplePosition = nil
	state.JumpStuckLowMotionTicks = 0
	state.JumpMoveToInFlightWaypointIndex = 0
	state.OrbitEscapeLowProgressTicks = 0
	return true
end

local function consumeReachedWaypoints(
	config: TBoidsConfig,
	state: TEntityState,
	boidPosition: Vector3
): boolean
	local shouldJump = false

	while state.Waypoints ~= nil and state.WaypointIndex <= #state.Waypoints do
		local activeWaypoint = state.Waypoints[state.WaypointIndex]
		if activeWaypoint == nil then
			break
		end

		local arrivalThreshold = getWaypointConsumeThreshold(config, activeWaypoint.Action)
		local toWaypoint = flatten(activeWaypoint.Position - boidPosition)
		if toWaypoint.Magnitude > arrivalThreshold then
			break
		end

		if activeWaypoint.Action == Enum.PathWaypointAction.Jump and state.LastJumpWaypointIndex ~= state.WaypointIndex then
			shouldJump = true
			state.LastJumpWaypointIndex = state.WaypointIndex
		end
		state.WaypointIndex += 1
	end

	return shouldJump
end

-- ── Public ──────────────────────────────────────────────────────────────────

--[=[
	@within BoidsHelper
	Starts or refreshes a boids session for a single entity.
	@param entity any -- Entity key used to track session state.
	@param sessionId string -- Shared session identifier for the group.
	@param targetPosition Vector3 -- Target position the group should steer toward.
	@param options TBoidsOptions -- Config and position callback used by the session.
	@return boolean -- Whether the entity was registered successfully.
]=]
function BoidsHelper.InitGroupMovement(
	entity: any,
	sessionId: string,
	targetPosition: Vector3,
	options: TBoidsOptions
): boolean
	-- Reject invalid setup before touching shared session state.
	if sessionId == "" or typeof(targetPosition) ~= "Vector3" then
		return false
	end

	-- Abort if the caller cannot provide a position for the entity.
	local entityPosition = getEntityPosition(entity, options)
	if entityPosition == nil then
		return false
	end

	-- Reuse the session so every entity in the group shares one target.
	local session = sessions[sessionId]
	if not session then
		session = createSession(sessionId, targetPosition)
	end
	session.TargetPosition = targetPosition

	local waypoints = computePathWaypoints(entity, targetPosition, options)
	if waypoints == nil then
		return false
	end

	registerEntity(session, entity, entityPosition, targetPosition, waypoints)
	return true
end

--[=[
	@within BoidsHelper
	Registers boids movement using a precomputed waypoint list (no synchronous path computation).
	@param entity any -- Entity key used to track session state.
	@param sessionId string -- Shared session identifier for the group.
	@param targetPosition Vector3 -- Strategic goal position for arrival and replan checks.
	@param waypoints { any } -- Path waypoints from pathfinding.
	@param options TBoidsOptions -- Config and position callback used by the session.
	@return boolean -- Whether the entity was registered successfully.
]=]
function BoidsHelper.InitGroupMovementWithWaypoints(
	entity: any,
	sessionId: string,
	targetPosition: Vector3,
	waypoints: { any },
	options: TBoidsOptions
): boolean
	if sessionId == "" or typeof(targetPosition) ~= "Vector3" then
		return false
	end

	local entityPosition = getEntityPosition(entity, options)
	if entityPosition == nil then
		return false
	end

	if waypoints == nil or type(waypoints) ~= "table" or #waypoints < MIN_WAYPOINT_COUNT then
		return false
	end

	local session = sessions[sessionId]
	if not session then
		session = createSession(sessionId, targetPosition)
	end
	session.TargetPosition = targetPosition

	registerEntity(session, entity, entityPosition, targetPosition, waypoints)
	return true
end

--[=[
	@within BoidsHelper
	Advances one entity's boids steering and reports whether it arrived.
	@param entity any -- Entity key used to look up session state.
	@param sessionId string -- Shared session identifier for the group.
	@param previousVelocity Vector3 -- Velocity returned on the previous tick.
	@param options TBoidsOptions -- Config and position callback used by the session.
	@return Vector3 -- Steering vector to apply for this tick.
	@return boolean -- Whether the entity has reached the arrival threshold.
	@return boolean -- Whether the jump action should fire on this tick (ignored when jumpMoveToWorld is non-nil; caller applies jump with MoveTo).
	@return Vector3? -- Flat forward unit (XZ) for lock-on: path tangent first; nil when not defined.
	@return Vector3? -- When non-nil, caller should Humanoid:MoveTo this world position for a Jump waypoint leg (after jump), until MoveToFinished.
]=]
function BoidsHelper.TickEntity(
	entity: any,
	sessionId: string,
	previousVelocity: Vector3,
	options: TBoidsOptions
): (Vector3, boolean, boolean, Vector3?, Vector3?)
	-- Missing session state means the caller should stop this movement path.
	local session = sessions[sessionId]
	if not session then
		return Vector3.zero, true, false, nil, nil
	end

	-- If the entity cannot be positioned, skip movement but keep the session alive.
	local boidPosition = getEntityPosition(entity, options)
	if not boidPosition then
		return Vector3.zero, false, false, nil, nil
	end

	-- Refresh the tracked state before computing any neighbor-based forces.
	updateEntityPosition(session, entity, boidPosition, previousVelocity)
	local entityState = session.Entities[entity]
	if entityState == nil then
		return Vector3.zero, false, false, nil, nil
	end

	local goalPosition = getGoalPosition(entity, session, options)
	local arrivalPosition = computeArrivalPosition(entity, goalPosition, options.Config)
	recomputePathIfNeeded(options.Config, entity, entityState, goalPosition, options, false)
	local shouldJump = consumeReachedWaypoints(options.Config, entityState, boidPosition)

	local activeWaypoint = if entityState.Waypoints ~= nil then entityState.Waypoints[entityState.WaypointIndex] else nil
	if activeWaypoint == nil then
		updateJumpStuckWatchdog(options.Config, entityState, boidPosition, nil)
		local hasRecomputed = recomputePathIfNeeded(options.Config, entity, entityState, goalPosition, options, true)
		if not hasRecomputed then
			local toArrival = flatten(arrivalPosition - boidPosition)
			if toArrival.Magnitude < options.Config.ArrivalThreshold then
				return Vector3.zero, true, false, nil, nil
			end
			local pathProgressForwardUnit: Vector3? =
				if toArrival.Magnitude >= PROGRESS_DIRECTION_MIN_LENGTH then toArrival.Unit else nil
			local force = calculateBoidsForce(
				options.Config,
				entity,
				session,
				boidPosition,
				previousVelocity,
				arrivalPosition,
				options,
				pathProgressForwardUnit
			)
			entityState.Velocity = force
			local lockOnForward = Orient.SafeUnit(toArrival)
			return force, false, shouldJump, lockOnForward, nil
		end

		activeWaypoint = if entityState.Waypoints ~= nil then entityState.Waypoints[entityState.WaypointIndex] else nil
		if activeWaypoint == nil then
			return Vector3.zero, false, shouldJump, nil, nil
		end
	end

	if updateJumpStuckWatchdog(options.Config, entityState, boidPosition, activeWaypoint) then
		shouldJump = true
	end

	local toActiveWaypoint = flatten(activeWaypoint.Position - boidPosition)
	local jumpApproachThreshold = getJumpWaypointArrivalThreshold(options.Config)
	if activeWaypoint.Action == Enum.PathWaypointAction.Jump
		and entityState.LastJumpWaypointIndex ~= entityState.WaypointIndex
		and toActiveWaypoint.Magnitude <= jumpApproachThreshold then
		shouldJump = true
		entityState.LastJumpWaypointIndex = entityState.WaypointIndex
	end

	local steeringTarget = activeWaypoint.Position
	if entityState.Waypoints ~= nil then
		steeringTarget = corridorSteeringTarget(
			entityState.Waypoints,
			entityState.WaypointIndex,
			activeWaypoint.Position,
			goalPosition,
			entityState.CorridorLaneSerial,
			options.Config
		)
	end

	local pathProgressForwardUnit = resolvePathProgressForwardUnit(
		boidPosition,
		activeWaypoint.Position,
		entityState.Waypoints,
		entityState.WaypointIndex,
		goalPosition
	)

	-- Store the latest force so the next tick can smooth against it.
	local force = calculateBoidsForce(
		options.Config,
		entity,
		session,
		boidPosition,
		previousVelocity,
		steeringTarget,
		options,
		pathProgressForwardUnit
	)
	entityState.Velocity = force

	local toArrival = flatten(arrivalPosition - boidPosition)
	local hasArrived = entityState.Waypoints ~= nil
		and entityState.WaypointIndex > #entityState.Waypoints
		and toArrival.Magnitude < options.Config.ArrivalThreshold

	local lockOnFlatForward = computeLockOnFlatForward(
		boidPosition,
		steeringTarget,
		activeWaypoint.Position,
		entityState.Waypoints,
		entityState.WaypointIndex,
		goalPosition,
		pathProgressForwardUnit
	)

	local jumpMoveToWorld: Vector3? = nil
	if options.Config.JumpUseMoveTo ~= false then
		if activeWaypoint.Action == Enum.PathWaypointAction.Jump then
			if entityState.JumpMoveToInFlightWaypointIndex ~= entityState.WaypointIndex then
				jumpMoveToWorld = activeWaypoint.Position
			end
		end
	end

	return force, hasArrived, shouldJump, lockOnFlatForward, jumpMoveToWorld
end

--[=[
	@within BoidsHelper
	Call when MovementService begins Humanoid:MoveTo for a Jump waypoint leg.
]=]
function BoidsHelper.NotifyJumpMoveToStarted(entity: any, sessionId: string)
	local session = sessions[sessionId]
	local entityState = if session ~= nil then session.Entities[entity] else nil
	if entityState == nil then
		return
	end
	entityState.JumpMoveToInFlightWaypointIndex = entityState.WaypointIndex
end

--[=[
	@within BoidsHelper
	Call when Jump MoveTo leg ends (finished, aborted, or timed out) so a new leg can be issued.
]=]
function BoidsHelper.NotifyJumpMoveToFinished(entity: any, sessionId: string)
	local session = sessions[sessionId]
	local entityState = if session ~= nil then session.Entities[entity] else nil
	if entityState == nil then
		return
	end
	entityState.JumpMoveToInFlightWaypointIndex = 0
end

--[=[
	@within BoidsHelper
	Removes a single entity from its session and destroys empty sessions.
	@param entity any -- Entity key used to track session state.
	@param sessionId string -- Shared session identifier for the group.
]=]
function BoidsHelper.CleanupEntity(entity: any, sessionId: string)
	-- If the entity never joined the session, there is nothing to remove.
	local session = sessions[sessionId]
	if not session or not session.Entities[entity] then
		return
	end

	-- Drop the entity and remove the session entirely once it becomes empty.
	session.Entities[entity] = nil
	session.EntityCount -= 1

	if session.EntityCount <= 0 then
		sessions[sessionId] = nil
	end
end

--[=[
	@within BoidsHelper
	Clears every tracked boids session.
]=]
function BoidsHelper.CleanupAllSessions()
	table.clear(sessions)
end

return BoidsHelper
