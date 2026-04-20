--!strict

--[[
	BoidsHelper - Executor helper for grouped MoveToPosition boids movement.

	Parallel to PathfindingHelper. Used by MoveToPositionExecutor when a group of
	NPCs share the same CommandGroupId. Maintains lightweight group sessions and
	computes Vector3 steering forces for Humanoid:Move().
]]

local BoidsConfig = require(script.Parent.Parent.Parent.Config.BoidsConfig)

type TEntityState = {
	Velocity: Vector3,
	Position: Vector3,
}

type TSession = {
	CommandGroupId: string,
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

local function steerFromDesired(desired: Vector3, previousVelocity: Vector3): Vector3
	local flatDesired = flatten(desired)
	if flatDesired.Magnitude <= 0 then
		return Vector3.zero
	end

	local targetVelocity = flatDesired.Unit * BoidsConfig.MaxSpeed
	return clampMagnitude(targetVelocity - previousVelocity, BoidsConfig.MaxForce)
end

local function seek(boidPosition: Vector3, targetPosition: Vector3, previousVelocity: Vector3): Vector3
	return steerFromDesired(flatten(targetPosition - boidPosition), previousVelocity)
end

local function getEntityPosition(entity: any, services: any): Vector3?
	local npc = services.NPCEntityFactory
	local modelRef = npc and npc:GetModelRef(entity)
	if not modelRef or not modelRef.Instance or not modelRef.Instance.PrimaryPart then
		return nil
	end

	return modelRef.Instance.PrimaryPart.Position
end

local function toVector3(value: any): Vector3?
	if typeof(value) == "Vector3" then
		return value
	end

	if type(value) == "table" and type(value.X) == "number" and type(value.Y) == "number" and type(value.Z) == "number" then
		return Vector3.new(value.X, value.Y, value.Z)
	end

	return nil
end

local function createSession(commandGroupId: string, targetPosition: Vector3): TSession
	local session = {
		CommandGroupId = commandGroupId,
		TargetPosition = targetPosition,
		Entities = {},
		EntityCount = 0,
	}
	sessions[commandGroupId] = session
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
		if distance > 0 and distance < BoidsConfig.SeparationRadius then
			steer += offset.Unit / distance
			count += 1
		end
	end

	if count > 0 then
		steer /= count
	end

	return steerFromDesired(steer, previousVelocity)
end

local function calculateAlignment(
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
		if distance > 0 and distance < BoidsConfig.NeighborRadius then
			velocitySum += state.Velocity
			count += 1
		end
	end

	if count == 0 then
		return Vector3.zero
	end

	return steerFromDesired(velocitySum / count, previousVelocity)
end

local function calculateCohesion(
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
		if distance > 0 and distance < BoidsConfig.NeighborRadius then
			positionSum += state.Position
			count += 1
		end
	end

	if count == 0 then
		return Vector3.zero
	end

	return seek(boidPosition, positionSum / count, previousVelocity)
end

local function calculateBoidsForce(
	entity: any,
	session: TSession,
	boidPosition: Vector3,
	previousVelocity: Vector3
): Vector3
	local separation = calculateSeparation(entity, session, boidPosition, previousVelocity)
	local alignment = calculateAlignment(entity, session, boidPosition, previousVelocity)
	local cohesion = calculateCohesion(entity, session, boidPosition, previousVelocity)
	local target = seek(boidPosition, session.TargetPosition, previousVelocity)

	local combined = separation * BoidsConfig.SeparationWeight
		+ alignment * BoidsConfig.AlignmentWeight
		+ cohesion * BoidsConfig.CohesionWeight
		+ target * BoidsConfig.TargetWeight

	local clamped = clampMagnitude(flatten(combined), BoidsConfig.MaxSpeed)
	local smoothed = previousVelocity:Lerp(clamped, BoidsConfig.Smoothing)

	if smoothed.Magnitude < BoidsConfig.MinSpeed then
		return Vector3.zero
	end

	return smoothed
end

function BoidsHelper.InitGroupMovement(entity: any, actionData: { [string]: any }, services: any, _userId: number?): boolean
	local commandGroupId = actionData.CommandGroupId
	if not commandGroupId then
		return false
	end

	local targetPosition = toVector3(actionData.Position)
	if not targetPosition then
		return false
	end

	local session = sessions[commandGroupId]
	if not session then
		session = createSession(commandGroupId, targetPosition)
	end

	registerEntity(session, entity, getEntityPosition(entity, services) or targetPosition)
	return true
end

function BoidsHelper.TickEntity(
	entity: any,
	commandGroupId: string,
	previousVelocity: Vector3,
	services: any
): (Vector3, boolean)
	local session = sessions[commandGroupId]
	if not session then
		return Vector3.zero, true
	end

	local boidPosition = getEntityPosition(entity, services)
	if not boidPosition then
		return Vector3.zero, false
	end

	updateEntityPosition(session, entity, boidPosition, previousVelocity)

	local toTarget = flatten(session.TargetPosition - boidPosition)
	if toTarget.Magnitude < BoidsConfig.ArrivalThreshold then
		return Vector3.zero, true
	end

	local force = calculateBoidsForce(entity, session, boidPosition, previousVelocity)
	session.Entities[entity].Velocity = force

	return force, false
end

function BoidsHelper.CleanupEntity(entity: any, commandGroupId: string, _services: any?)
	local session = sessions[commandGroupId]
	if not session or not session.Entities[entity] then
		return
	end

	session.Entities[entity] = nil
	session.EntityCount -= 1

	if session.EntityCount <= 0 then
		sessions[commandGroupId] = nil
	end
end

function BoidsHelper.CleanupAllSessions()
	table.clear(sessions)
end

return BoidsHelper
