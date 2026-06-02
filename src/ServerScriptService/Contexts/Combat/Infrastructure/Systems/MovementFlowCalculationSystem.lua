--!strict

local MovementFlowCalculationSystem = {}
MovementFlowCalculationSystem.__index = MovementFlowCalculationSystem

function MovementFlowCalculationSystem.new(entityFactory: any)
	local self = setmetatable({}, MovementFlowCalculationSystem)
	self._entityFactory = entityFactory
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
	local goalPosition = if type(intent) == "table" then intent.GoalPosition else nil
	local movementMode = if type(intent) == "table" then intent.MovementMode else nil
	local requestedAt = if type(intent) == "table" and type(intent.RequestedAt) == "number" then intent.RequestedAt else now
	local status = if type(intent) == "table" then intent.Status else nil

	if status == "Cancelled" then
		self._entityFactory:Set(entity, "ApplyState", {
			RequestedAt = requestedAt,
			UpdatedAt = now,
			Status = "Cancelled",
			IsMoving = false,
			IsDone = false,
			FailureReason = intent.Reason,
		}, "Movement")
		return
	end

	if typeof(goalPosition) ~= "Vector3" or type(movementMode) ~= "string" or movementMode == "" then
		self:_WriteFailedState(entity, requestedAt, now, "InvalidMoveIntent")
		return
	end

	self._entityFactory:Set(entity, "PathRuntimeState", {
		Mode = movementMode,
		GoalPosition = goalPosition,
		RequestedAt = requestedAt,
		StartedAt = now,
		UpdatedAt = now,
		Status = "Ready",
		FailureReason = nil,
	}, "Movement")
	self._entityFactory:Set(entity, "FlowCalculationState", {
		RequestedAt = requestedAt,
		UpdatedAt = now,
		Status = "Ready",
		IsDone = false,
		FailureReason = nil,
	}, "Movement")
	self._entityFactory:Set(entity, "ApplyState", {
		RequestedAt = requestedAt,
		UpdatedAt = now,
		Status = "Ready",
		IsMoving = true,
		IsDone = false,
		FailureReason = nil,
	}, "Movement")
end

function MovementFlowCalculationSystem:_WriteFailedState(entity: number, requestedAt: number, now: number, reason: string)
	self._entityFactory:Set(entity, "FlowCalculationState", {
		RequestedAt = requestedAt,
		UpdatedAt = now,
		Status = "Failed",
		IsDone = false,
		FailureReason = reason,
	}, "Movement")
	self._entityFactory:Set(entity, "ApplyState", {
		RequestedAt = requestedAt,
		UpdatedAt = now,
		Status = "Failed",
		IsMoving = false,
		IsDone = false,
		FailureReason = reason,
	}, "Movement")
end

function MovementFlowCalculationSystem:_Get(entity: number, key: string, featureName: string): any
	local result = self._entityFactory:Get(entity, key, featureName)
	return if result.success then result.value else nil
end

return MovementFlowCalculationSystem
