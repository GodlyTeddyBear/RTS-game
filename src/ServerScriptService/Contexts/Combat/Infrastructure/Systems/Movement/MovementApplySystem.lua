--!strict

local MovementApplySystem = {}
MovementApplySystem.__index = MovementApplySystem

function MovementApplySystem.new(entityFactory: any, dependencies: any)
	local self = setmetatable({}, MovementApplySystem)
	self._entityFactory = entityFactory
	self._applyBridgeService = dependencies.ApplyBridgeService
	return self
end

function MovementApplySystem:Run()
	-- READS: Movement.ApplyState [AUTHORITATIVE]
	-- WRITES: Movement.ApplyResult [AUTHORITATIVE]
	local queryResult = self._entityFactory:Query({
		FeatureName = "Movement",
		Keys = { "ApplyState" },
	})
	if not queryResult.success then
		return
	end

	local now = os.clock()
	for _, entity in ipairs(queryResult.value) do
		self:_RunEntity(entity, now)
	end
end

function MovementApplySystem:_RunEntity(entity: number, now: number)
	local applyState = self:_Get(entity, "ApplyState", "Movement")
	if type(applyState) ~= "table" then
		return
	end

	local status = applyState.Status
	if status == "Cancelled" or status == "Failed" or status == "Done" then
		self._applyBridgeService:Stop(entity)
		self:_WriteResult(entity, applyState, now, status, false, applyState.FailureReason)
		return
	end
	if status ~= "Running" then
		return
	end

	local runtimeState = self:_Get(entity, "PathRuntimeState", "Movement")
	if type(runtimeState) == "table" and runtimeState.Mode == "Path" then
		self:_WriteResult(entity, applyState, now, "Running", true, nil)
		return
	end

	local applied, reason = self._applyBridgeService:Apply(self._entityFactory, entity, applyState)
	self:_WriteResult(entity, applyState, now, if applied then "Running" else "Failed", applied, reason)
end

function MovementApplySystem:_WriteResult(entity: number, applyState: any, now: number, status: string, isMoving: boolean, reason: string?)
	self._entityFactory:Set(entity, "ApplyResult", {
		RequestedAt = applyState.RequestedAt,
		UpdatedAt = now,
		Status = status,
		IsMoving = isMoving,
		IsDone = status == "Done",
		FailureReason = reason,
	}, "Movement")
end

function MovementApplySystem:_Get(entity: number, key: string, featureName: string): any
	local result = self._entityFactory:Get(entity, key, featureName)
	return if result.success then result.value else nil
end

return MovementApplySystem
