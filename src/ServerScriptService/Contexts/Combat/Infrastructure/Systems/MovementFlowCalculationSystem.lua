--!strict

local MovementFlowCalculationSystem = {}
MovementFlowCalculationSystem.__index = MovementFlowCalculationSystem

function MovementFlowCalculationSystem.new(entityFactory: any, dependencies: any)
	local self = setmetatable({}, MovementFlowCalculationSystem)
	self._entityFactory = entityFactory
	self._entityContext = dependencies.EntityContext
	self._actorReadService = dependencies.ActorReadService
	self._flowfieldService = dependencies.FlowfieldService
	self._pathRuntimeService = dependencies.PathRuntimeService
	return self
end

function MovementFlowCalculationSystem:Run()
	-- READS: Movement.MoveIntent [AUTHORITATIVE], Movement.FlowGridState [AUTHORITATIVE]
	-- WRITES: Movement.PathRuntimeState [AUTHORITATIVE], Movement.FlowCalculationState [AUTHORITATIVE], Movement.ApplyState [AUTHORITATIVE]
	local queryResult = self._entityFactory:Query({
		FeatureName = "Movement",
		Keys = { "MoveIntent" },
	})
	if not queryResult.success then
		return
	end

	local now = os.clock()
	for _, entity in ipairs(queryResult.value) do
		self:_RunEntity(entity, now)
	end
end

function MovementFlowCalculationSystem:_RunEntity(entity: number, now: number)
	local intent = self:_Get(entity, "MoveIntent", "Movement")
	local requestedAt = if type(intent) == "table" and type(intent.RequestedAt) == "number" then intent.RequestedAt else now
	local goalPosition = if type(intent) == "table" then intent.GoalPosition else nil
	local requestedMode = if type(intent) == "table" then intent.MovementMode else nil
	if type(intent) ~= "table" or intent.Status == "Cancelled" then
		self:_WriteApplyState(entity, requestedAt, now, "Cancelled", nil, nil, false, "MovementCancelled")
		return
	end
	if typeof(goalPosition) ~= "Vector3" or type(requestedMode) ~= "string" then
		self:_WriteApplyState(entity, requestedAt, now, "Failed", nil, nil, false, "InvalidMoveIntent")
		return
	end

	local mode = self:_ResolveMode(requestedMode, goalPosition)
	if mode == "Path" then
		self:_CalculatePath(entity, goalPosition, requestedAt, now)
		return
	end
	if mode == "Boids" then
		self:_CalculateFlow(entity, goalPosition, requestedAt, now)
		return
	end
	self:_WriteApplyState(entity, requestedAt, now, "Failed", nil, nil, false, "InvalidMovementMode")
end

function MovementFlowCalculationSystem:_CalculatePath(entity: number, goalPosition: Vector3, requestedAt: number, now: number)
	local started, reason = self._pathRuntimeService:StartOrRetarget(self._entityFactory, entity, goalPosition)
	if not started then
		self:_WriteApplyState(entity, requestedAt, now, "Failed", nil, nil, false, reason or "PathStartFailed")
		return
	end
	local status, pollReason = self._pathRuntimeService:Poll(entity)
	self:_WriteRuntimeState(entity, "Path", goalPosition, requestedAt, now, status, pollReason)
	self:_WriteApplyState(entity, requestedAt, now, status, nil, nil, status == "Running", pollReason)
end

function MovementFlowCalculationSystem:_CalculateFlow(entity: number, goalPosition: Vector3, requestedAt: number, now: number)
	local position = self._actorReadService:GetPosition(self._entityFactory, self._entityContext, entity)
	if position == nil then
		self:_WriteApplyState(entity, requestedAt, now, "Failed", nil, nil, false, "MissingActorPosition")
		return
	end

	local _attachment, attachReason = self._flowfieldService:Attach(entity, goalPosition)
	if attachReason ~= nil then
		self:_WriteApplyState(entity, requestedAt, now, "Failed", nil, nil, false, attachReason)
		return
	end

	local velocityXZ = self._flowfieldService:Sample(entity, position)
	local targetPosition = if velocityXZ ~= nil and velocityXZ.Magnitude > 0
		then self._flowfieldService:SanitizeTarget(position + Vector3.new(velocityXZ.X, 0, velocityXZ.Y) * 4)
		else nil
	self:_WriteRuntimeState(entity, "Boids", goalPosition, requestedAt, now, "Running", nil)
	self:_WriteApplyState(entity, requestedAt, now, "Running", targetPosition, velocityXZ, targetPosition ~= nil, nil)
end

function MovementFlowCalculationSystem:_ResolveMode(requestedMode: string, goalPosition: Vector3): string?
	if requestedMode == "Path" or requestedMode == "Boids" then
		return requestedMode
	end
	if requestedMode ~= "Any" then
		return nil
	end
	return if self._actorReadService:CountFlowEligiblePeers(self._entityFactory, goalPosition) >= 2 then "Boids" else "Path"
end

function MovementFlowCalculationSystem:_WriteRuntimeState(
	entity: number,
	mode: string,
	goalPosition: Vector3,
	requestedAt: number,
	now: number,
	status: string,
	reason: string?
)
	self._entityFactory:Set(entity, "PathRuntimeState", {
		Mode = mode,
		GoalPosition = goalPosition,
		RequestedAt = requestedAt,
		StartedAt = now,
		UpdatedAt = now,
		Status = status,
		FailureReason = reason,
	}, "Movement")
	self._entityFactory:Set(entity, "FlowCalculationState", {
		RequestedAt = requestedAt,
		UpdatedAt = now,
		Status = status,
		IsDone = status == "Done",
		FailureReason = reason,
	}, "Movement")
end

function MovementFlowCalculationSystem:_WriteApplyState(
	entity: number,
	requestedAt: number,
	now: number,
	status: string,
	targetPosition: Vector3?,
	velocityXZ: Vector2?,
	isMoving: boolean,
	reason: string?
)
	self._entityFactory:Set(entity, "ApplyState", {
		RequestedAt = requestedAt,
		UpdatedAt = now,
		Status = status,
		TargetPosition = targetPosition,
		VelocityXZ = velocityXZ,
		IsMoving = isMoving,
		IsDone = status == "Done",
		FailureReason = reason,
	}, "Movement")
end

function MovementFlowCalculationSystem:_Get(entity: number, key: string, featureName: string): any
	local result = self._entityFactory:Get(entity, key, featureName)
	return if result.success then result.value else nil
end

return MovementFlowCalculationSystem
