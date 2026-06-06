--!strict

local MovementFinalizeSystem = {}
MovementFinalizeSystem.__index = MovementFinalizeSystem

function MovementFinalizeSystem.new(entityFactory: any, dependencies: any)
	local self = setmetatable({}, MovementFinalizeSystem)
	self._entityFactory = entityFactory
	self._pathRuntimeService = dependencies.PathRuntimeService
	self._flowfieldService = dependencies.FlowfieldService
	self._applyBridgeService = dependencies.ApplyBridgeService
	return self
end

function MovementFinalizeSystem:Run()
	-- READS: Movement.MoveIntent [AUTHORITATIVE], Movement.ApplyResult [AUTHORITATIVE], Movement.PathRuntimeState [AUTHORITATIVE]
	-- WRITES: Movement.CompletedIntent [DERIVED], Movement.MoveIntent [AUTHORITATIVE], Movement.ApplyState [AUTHORITATIVE], Movement.ApplyResult [AUTHORITATIVE]
	local queryResult = self._entityFactory:Query({
		FeatureName = "Movement",
		Keys = { "MoveIntent", "ApplyResult" },
	})
	if not queryResult.success then
		return
	end

	local now = os.clock()
	for _, entity in ipairs(queryResult.value) do
		self:_RunEntity(entity, now)
	end
end

function MovementFinalizeSystem:_RunEntity(entity: number, now: number)
	local intent = self:_Get(entity, "MoveIntent", "Movement")
	local applyResult = self:_Get(entity, "ApplyResult", "Movement")
	if type(intent) ~= "table" or type(applyResult) ~= "table" then
		return
	end

	local status = applyResult.Status
	if status == "Done" then
		self:_StopRuntime(entity)
		self:_WriteCompletedIntent(entity, intent, now)
		self:_ClearActiveMovement(entity)
		self:_WriteFinalApplyResult(entity, applyResult, now, "Done", nil)
		return
	end

	if status == "Failed" or status == "Cancelled" then
		self:_StopRuntime(entity)
		self:_ClearActiveMovement(entity)
		self:_WriteFinalApplyResult(entity, applyResult, now, status, applyResult.FailureReason)
	end
end

function MovementFinalizeSystem:_StopRuntime(entity: number)
	if self._pathRuntimeService ~= nil then
		self._pathRuntimeService:Stop(entity)
	end
	if self._flowfieldService ~= nil then
		self._flowfieldService:Detach(entity)
	end
	if self._applyBridgeService ~= nil then
		self._applyBridgeService:Stop(entity)
	end
end

function MovementFinalizeSystem:_WriteCompletedIntent(entity: number, intent: any, now: number)
	local runtimeState = self:_Get(entity, "PathRuntimeState", "Movement")
	self._entityFactory:Set(entity, "CompletedIntent", {
		ActionId = intent.ActionId,
		RequestedAt = intent.RequestedAt,
		GoalPosition = intent.GoalPosition,
		CompletedAt = now,
		Mode = if type(runtimeState) == "table" then runtimeState.Mode else intent.MovementMode,
	}, "Movement")
end

function MovementFinalizeSystem:_ClearActiveMovement(entity: number)
	self._entityFactory:Remove(entity, "MoveIntent", "Movement")
	self._entityFactory:Remove(entity, "ApplyState", "Movement")
end

function MovementFinalizeSystem:_WriteFinalApplyResult(entity: number, applyResult: any, now: number, status: string, reason: string?)
	self._entityFactory:Set(entity, "ApplyResult", {
		RequestedAt = applyResult.RequestedAt,
		UpdatedAt = now,
		Status = status,
		IsMoving = false,
		IsDone = status == "Done",
		FailureReason = reason,
	}, "Movement")
end

function MovementFinalizeSystem:_Get(entity: number, key: string, featureName: string): any
	local result = self._entityFactory:Get(entity, key, featureName)
	return if result.success then result.value else nil
end

return MovementFinalizeSystem
