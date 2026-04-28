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
}

type TEntityState = {
	Velocity: Vector3,
	Position: Vector3,
}

type TSession = {
	SessionId: string,
	TargetPosition: Vector3,
	Entities: { [any]: TEntityState },
	EntityCount: number,
}

-- ── Private ────────────────────────────────────────────────────────────────

local BoidsHelper = {}

local sessions: { [string]: TSession } = {}

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

local function steerFromDesired(config: TBoidsConfig, desired: Vector3, previousVelocity: Vector3): Vector3
	local flatDesired = flatten(desired)
	if flatDesired.Magnitude <= 0 then
		return Vector3.zero
	end

	local targetVelocity = flatDesired.Unit * config.MaxSpeed
	return clampMagnitude(targetVelocity - previousVelocity, config.MaxForce)
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

local function createSession(sessionId: string, targetPosition: Vector3): TSession
	local session = {
		SessionId = sessionId,
		TargetPosition = targetPosition,
		Entities = {},
		EntityCount = 0,
	}
	sessions[sessionId] = session
	return session
end

-- Register an entity once and seed its tracked velocity and position.
local function registerEntity(session: TSession, entity: any, position: Vector3)
	if not session.Entities[entity] then
		session.EntityCount += 1
	end

	session.Entities[entity] = {
		Velocity = Vector3.zero,
		Position = position,
	}
end

local function updateEntityPosition(session: TSession, entity: any, position: Vector3, velocity: Vector3)
	local state = session.Entities[entity]
	if not state then
		registerEntity(session, entity, position)
		return
	end

	state.Position = position
	state.Velocity = velocity
end

-- Calculate the separation force by repelling the entity from close neighbors.
local function calculateSeparation(
	config: TBoidsConfig,
	entity: any,
	session: TSession,
	boidPosition: Vector3,
	previousVelocity: Vector3
): Vector3
	local steer = Vector3.zero
	local count = 0

	for otherEntity, state in session.Entities do
		-- Ignore self so the entity never repels from its own position.
		if otherEntity == entity then
			continue
		end

		local offset = flatten(boidPosition - state.Position)
		local distance = offset.Magnitude
		-- Only neighbors inside the separation radius contribute to crowding.
		if distance > 0 and distance < config.SeparationRadius then
			steer += offset.Unit / distance
			count += 1
		end
	end

	if count > 0 then
		steer /= count
	end

	return steerFromDesired(config, steer, previousVelocity)
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
	previousVelocity: Vector3
): Vector3
	-- Resolve each influence separately so the weights stay easy to tune.
	local separation = calculateSeparation(config, entity, session, boidPosition, previousVelocity)
	local alignment = calculateAlignment(config, entity, session, boidPosition, previousVelocity)
	local cohesion = calculateCohesion(config, entity, session, boidPosition, previousVelocity)
	local target = seek(config, boidPosition, session.TargetPosition, previousVelocity)

	-- Combine the weighted forces before smoothing and clamping.
	local combined = separation * config.SeparationWeight
		+ alignment * config.AlignmentWeight
		+ cohesion * config.CohesionWeight
		+ target * config.TargetWeight

	-- Cap the force and dampen jitter so movement changes stay stable frame to frame.
	local clamped = clampMagnitude(flatten(combined), config.MaxSpeed)
	local smoothed = previousVelocity:Lerp(clamped, config.Smoothing)

	-- Treat tiny residual motion as idle so callers can stop moving the humanoid.
	if smoothed.Magnitude < config.MinSpeed then
		return Vector3.zero
	end

	return smoothed
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

	registerEntity(session, entity, entityPosition)
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
]=]
function BoidsHelper.TickEntity(
	entity: any,
	sessionId: string,
	previousVelocity: Vector3,
	options: TBoidsOptions
): (Vector3, boolean)
	-- Missing session state means the caller should stop this movement path.
	local session = sessions[sessionId]
	if not session then
		return Vector3.zero, true
	end

	-- If the entity cannot be positioned, skip movement but keep the session alive.
	local boidPosition = getEntityPosition(entity, options)
	if not boidPosition then
		return Vector3.zero, false
	end

	-- Refresh the tracked state before computing any neighbor-based forces.
	updateEntityPosition(session, entity, boidPosition, previousVelocity)

	-- Arrival uses only horizontal distance so elevation does not block completion.
	local toTarget = flatten(session.TargetPosition - boidPosition)
	if toTarget.Magnitude < options.Config.ArrivalThreshold then
		return Vector3.zero, true
	end

	-- Store the latest force so the next tick can smooth against it.
	local force = calculateBoidsForce(options.Config, entity, session, boidPosition, previousVelocity)
	session.Entities[entity].Velocity = force

	return force, false
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
