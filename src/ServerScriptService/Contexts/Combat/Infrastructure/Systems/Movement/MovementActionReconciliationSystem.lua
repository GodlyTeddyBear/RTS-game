--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AISharedContract = require(ReplicatedStorage.Contexts.AI.AISharedContract)

local MovementActionReconciliationSystem = {}
MovementActionReconciliationSystem.__index = MovementActionReconciliationSystem

local RUNNING_ACTION_STATUSES = {
	[AISharedContract.ActionStatus.Requested] = true,
	[AISharedContract.ActionStatus.Running] = true,
}

function MovementActionReconciliationSystem.new(entityFactory: any, dependencies: any)
	local self = setmetatable({}, MovementActionReconciliationSystem)
	self._entityFactory = entityFactory
	self._pathRuntimeService = dependencies.PathRuntimeService
	self._flowfieldService = dependencies.FlowfieldService
	self._applyBridgeService = dependencies.ApplyBridgeService
	return self
end

function MovementActionReconciliationSystem:Run()
	-- READS: AI.ActionState [AUTHORITATIVE], AI.ActionIntent [AUTHORITATIVE], Movement.MoveIntent [AUTHORITATIVE], Combat.AttackState [AUTHORITATIVE]
	-- WRITES: Movement.MoveIntent [AUTHORITATIVE], Movement.ApplyState [AUTHORITATIVE], Movement.ApplyResult [AUTHORITATIVE]
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

function MovementActionReconciliationSystem:_RunEntity(entity: number, now: number)
	local moveIntent = self:_Get(entity, "MoveIntent", "Movement")
	local actionState = self:_Get(entity, AISharedContract.Components.ActionState, AISharedContract.FeatureName)
	if type(moveIntent) ~= "table" or type(actionState) ~= "table" then
		return
	end

	local actionId = self:_ResolveEffectiveActionId(entity, actionState)
	if type(actionId) ~= "string" or actionId == "" or actionId == moveIntent.ActionId then
		return
	end

	local shouldStop = RUNNING_ACTION_STATUSES[actionState.Status] == true or self:_HasActiveAttack(entity, actionId)
	if not shouldStop then
		return
	end

	self:_StopRuntime(entity)
	self._entityFactory:Remove(entity, "MoveIntent", "Movement")
	self._entityFactory:Remove(entity, "ApplyState", "Movement")
	self._entityFactory:Set(entity, "ApplyResult", {
		RequestedAt = if type(moveIntent.RequestedAt) == "number" then moveIntent.RequestedAt else now,
		UpdatedAt = now,
		Status = "Cancelled",
		IsMoving = false,
		IsDone = false,
		FailureReason = "ActionChanged",
	}, "Movement")
end

function MovementActionReconciliationSystem:_ResolveEffectiveActionId(entity: number, actionState: any): string?
	local actionIntent = self:_Get(entity, AISharedContract.Components.ActionIntent, AISharedContract.FeatureName)
	if type(actionIntent) == "table" and type(actionIntent.ActionId) == "string" and actionIntent.ActionId ~= "" then
		return actionIntent.ActionId
	end
	if self:_HasActiveAttack(entity, "Attack") then
		return "Attack"
	end
	if type(actionState.ActionId) == "string" and actionState.ActionId ~= "" then
		return actionState.ActionId
	end

	return nil
end

function MovementActionReconciliationSystem:_HasActiveAttack(entity: number, actionId: string): boolean
	if actionId ~= "Attack" then
		return false
	end

	local attackState = self:_Get(entity, "AttackState", "Combat")
	return type(attackState) == "table" and attackState.Phase ~= "Completed" and attackState.Phase ~= "Failed"
end

function MovementActionReconciliationSystem:_StopRuntime(entity: number)
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

function MovementActionReconciliationSystem:_Get(entity: number, key: string, featureName: string): any
	local result = self._entityFactory:Get(entity, key, featureName)
	return if result.success then result.value else nil
end

return MovementActionReconciliationSystem
