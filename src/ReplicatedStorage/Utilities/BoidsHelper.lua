--!strict

--[=[
	@class BoidsHelper
	Maintains lightweight grouped steering sessions and computes Vector3 movement
	for callers that supply config and position access.
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

local BoidsHelper = {}

local sessions: { [string]: TSession } = {}

local function flatten(vector: Vector3): Vector3
	return Vector3.new(vector.X, 0, vector.Z)
end

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
		if otherEntity == entity then
			continue
		end

		local offset = flatten(boidPosition - state.Position)
		local distance = offset.Magnitude
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
		if otherEntity == entity then
			continue
		end

		local offset = flatten(boidPosition - state.Position)
		local distance = offset.Magnitude
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
		if otherEntity == entity then
			continue
		end

		local offset = flatten(boidPosition - state.Position)
		local distance = offset.Magnitude
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

local function calculateBoidsForce(
	config: TBoidsConfig,
	entity: any,
	session: TSession,
	boidPosition: Vector3,
	previousVelocity: Vector3
): Vector3
	local separation = calculateSeparation(config, entity, session, boidPosition, previousVelocity)
	local alignment = calculateAlignment(config, entity, session, boidPosition, previousVelocity)
	local cohesion = calculateCohesion(config, entity, session, boidPosition, previousVelocity)
	local target = seek(config, boidPosition, session.TargetPosition, previousVelocity)

	local combined = separation * config.SeparationWeight
		+ alignment * config.AlignmentWeight
		+ cohesion * config.CohesionWeight
		+ target * config.TargetWeight

	local clamped = clampMagnitude(flatten(combined), config.MaxSpeed)
	local smoothed = previousVelocity:Lerp(clamped, config.Smoothing)

	if smoothed.Magnitude < config.MinSpeed then
		return Vector3.zero
	end

	return smoothed
end

function BoidsHelper.InitGroupMovement(
	entity: any,
	sessionId: string,
	targetPosition: Vector3,
	options: TBoidsOptions
): boolean
	if sessionId == "" or typeof(targetPosition) ~= "Vector3" then
		return false
	end

	local entityPosition = getEntityPosition(entity, options)
	if entityPosition == nil then
		return false
	end

	local session = sessions[sessionId]
	if not session then
		session = createSession(sessionId, targetPosition)
	end

	registerEntity(session, entity, entityPosition)
	return true
end

function BoidsHelper.TickEntity(
	entity: any,
	sessionId: string,
	previousVelocity: Vector3,
	options: TBoidsOptions
): (Vector3, boolean)
	local session = sessions[sessionId]
	if not session then
		return Vector3.zero, true
	end

	local boidPosition = getEntityPosition(entity, options)
	if not boidPosition then
		return Vector3.zero, false
	end

	updateEntityPosition(session, entity, boidPosition, previousVelocity)

	local toTarget = flatten(session.TargetPosition - boidPosition)
	if toTarget.Magnitude < options.Config.ArrivalThreshold then
		return Vector3.zero, true
	end

	local force = calculateBoidsForce(options.Config, entity, session, boidPosition, previousVelocity)
	session.Entities[entity].Velocity = force

	return force, false
end

function BoidsHelper.CleanupEntity(entity: any, sessionId: string)
	local session = sessions[sessionId]
	if not session or not session.Entities[entity] then
		return
	end

	session.Entities[entity] = nil
	session.EntityCount -= 1

	if session.EntityCount <= 0 then
		sessions[sessionId] = nil
	end
end

function BoidsHelper.CleanupAllSessions()
	table.clear(sessions)
end

return BoidsHelper
