--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local CombatMovementConfig = require(ReplicatedStorage.Contexts.Combat.Config.CombatMovementConfig)
local ServerScheduler = require(ServerScriptService.Scheduler.ServerScheduler)
local UnitConfig = require(ReplicatedStorage.Contexts.Unit.Config.UnitConfig)

local MovementApplySystem = {}
MovementApplySystem.__index = MovementApplySystem

local GOAL_POSITION_EPSILON = 0.01

function MovementApplySystem.new(entityFactory: any, dependencies: any)
	local self = setmetatable({}, MovementApplySystem)
	self._entityFactory = entityFactory
	self._entityContext = dependencies.EntityContext
	self._movementService = dependencies.MovementService
	return self
end

function MovementApplySystem:Run()
	-- READS: Movement.MoveIntent [AUTHORITATIVE], Movement.PathRuntimeState [AUTHORITATIVE], Movement.ApplyState [AUTHORITATIVE], Unit.PathState [AUTHORITATIVE]
	-- WRITES: Movement.ApplyResult [AUTHORITATIVE], Unit.PathState [AUTHORITATIVE], Unit.AnimationState [DERIVED], Unit.AnimationLooping [DERIVED], Entity.DirtyTag
	local queryResult = self._entityFactory:Query({
		FeatureName = "Movement",
		Keys = { "MoveIntent", "PathRuntimeState", "ApplyState" },
	})
	if not queryResult.success then
		return
	end

	local deltaTime = ServerScheduler:GetDeltaTime()
	local now = os.clock()
	for _, entity in ipairs(queryResult.value) do
		self:_RunEntity(entity, now, deltaTime)
	end
end

function MovementApplySystem:_RunEntity(entity: number, now: number, deltaTime: number)
	if type(self:_Get(entity, "PathState", "Unit")) ~= "table" then
		return
	end

	local applyState = self:_Get(entity, "ApplyState", "Movement")
	local runtimeState = self:_Get(entity, "PathRuntimeState", "Movement")
	local intent = self:_Get(entity, "MoveIntent", "Movement")
	local goalPosition = if type(runtimeState) == "table" then runtimeState.GoalPosition else nil
	local movementMode = if type(runtimeState) == "table" then runtimeState.Mode else nil
	local requestedAt = if type(intent) == "table" and type(intent.RequestedAt) == "number" then intent.RequestedAt else now

	if type(applyState) ~= "table" or applyState.Status ~= "Ready" then
		if type(applyState) == "table" and applyState.Status == "Cancelled" then
			self:_Cancel(entity, requestedAt, now, applyState.FailureReason or "MovementCancelled")
		end
		if type(applyState) == "table" and applyState.Status == "Failed" then
			self:_Stop(entity, requestedAt, now, applyState.FailureReason or "MovementApplyFailed")
		end
		return
	end

	if typeof(goalPosition) ~= "Vector3" or type(movementMode) ~= "string" or movementMode == "" then
		self:_Stop(entity, requestedAt, now, "InvalidMovementRuntimeState")
		return
	end

	local started, startReason = self._movementService:StartAdvance(
		self:_BuildMovementBinding(entity),
		movementMode,
		goalPosition
	)
	if not started then
		self:_Stop(entity, requestedAt, now, startReason or "MovementStartFailed")
		return
	end

	local isDone, stepReason = self._movementService:StepAdvance(self:_BuildMovementBinding(entity), {
		DeltaTime = deltaTime,
	})
	if stepReason ~= nil then
		self:_Stop(entity, requestedAt, now, stepReason)
		return
	end

	self:_SetPathMoving(entity, true)
	self:_SetUnitPresentation(entity, "Walk", true)
	self:_WriteApplyResult(entity, requestedAt, now, "Running", true, false, nil)

	if isDone then
		self._movementService:StopMovement(self:_BuildMovementBinding(entity))
		self:_ClearUnitGoal(entity)
		self:_SetUnitPresentation(entity, "Idle", true)
		self:_WriteApplyResult(entity, requestedAt, now, "Done", false, true, nil)
	end
end

function MovementApplySystem:_Stop(entity: number, requestedAt: number, now: number, reason: string)
	self._movementService:StopMovement(self:_BuildMovementBinding(entity))
	self:_SetPathMoving(entity, false)
	self:_SetUnitPresentation(entity, "Idle", true)
	self:_WriteApplyResult(entity, requestedAt, now, "Failed", false, false, reason)
end

function MovementApplySystem:_Cancel(entity: number, requestedAt: number, now: number, reason: string)
	self._movementService:StopMovement(self:_BuildMovementBinding(entity))
	self:_SetPathMoving(entity, false)
	self:_SetUnitPresentation(entity, "Idle", true)
	self:_WriteApplyResult(entity, requestedAt, now, "Cancelled", false, false, reason)
end

function MovementApplySystem:_BuildMovementBinding(entity: number): any
	return {
		ActorKey = "Unit:" .. tostring(entity),
		EntityId = entity,
		GetPathState = function()
			return self:_Get(entity, "PathState", "Unit")
		end,
		SetPathMoving = function(_binding: any, isMoving: boolean)
			self:_SetPathMoving(entity, isMoving)
		end,
		GetModelRef = function()
			local modelRef = self:_Get(entity, "ModelRef", "Entity")
			if type(modelRef) == "table" and modelRef.Model ~= nil then
				return modelRef
			end

			local boundResult = self._entityContext:GetBoundInstance(entity)
			local boundInstance = if boundResult.success then boundResult.value else nil
			return if boundInstance ~= nil and boundInstance:IsA("Model") then { Model = boundInstance } else nil
		end,
		GetCurrentMoveSpeed = function()
			local currentMoveSpeed = self:_Get(entity, "CurrentMoveSpeed", "Unit")
			return if type(currentMoveSpeed) == "table" then currentMoveSpeed.Value else 0
		end,
		GetAgentParams = function()
			local identity = self:_Get(entity, "Identity", "Entity")
			local definitionId = if type(identity) == "table" then identity.DefinitionId else nil
			local definition = if type(definitionId) == "string" then UnitConfig.Definitions[definitionId] else nil
			local roleName = if definition ~= nil then definition.Role else nil
			local config = if roleName ~= nil then CombatMovementConfig.AGENT_PARAMS_BY_UNIT_ROLE[roleName] else nil
			return if config ~= nil then config else CombatMovementConfig.DEFAULT_AGENT_PARAMS
		end,
		CountFlowEligiblePeers = function(_binding: any, goalPosition: Vector3): number
			local groupSize = 0
			local queryResult = self._entityFactory:Query({
				FeatureName = "Unit",
				Keys = { "Role", "PathState" },
			})
			if not queryResult.success then
				return groupSize
			end

			for _, candidateEntity in ipairs(queryResult.value) do
				local pathState = self:_Get(candidateEntity, "PathState", "Unit")
				local candidateGoal = if type(pathState) == "table" then pathState.GoalPosition else nil
				if candidateGoal == nil or (candidateGoal - goalPosition).Magnitude > GOAL_POSITION_EPSILON then
					continue
				end

				local identity = self:_Get(candidateEntity, "Identity", "Entity")
				local definitionId = if type(identity) == "table" then identity.DefinitionId else nil
				local definition = if type(definitionId) == "string" then UnitConfig.Definitions[definitionId] else nil
				if definition ~= nil and (definition.MovementMode == "Any" or definition.MovementMode == "Boids") then
					groupSize += 1
				end
			end
			return groupSize
		end,
	}
end

function MovementApplySystem:_SetPathMoving(entity: number, isMoving: boolean)
	local state = self:_Get(entity, "PathState", "Unit") or {}
	self._entityFactory:Set(entity, "PathState", {
		GoalPosition = state.GoalPosition,
		RequestedGoalPosition = state.RequestedGoalPosition,
		GoalRevision = state.GoalRevision or 0,
		FailedGoalRevision = state.FailedGoalRevision,
		IsMoving = isMoving,
	}, "Unit")
	self:_MarkDirty(entity)
end

function MovementApplySystem:_ClearUnitGoal(entity: number)
	local state = self:_Get(entity, "PathState", "Unit") or {}
	self._entityFactory:Set(entity, "PathState", {
		GoalPosition = nil,
		RequestedGoalPosition = nil,
		GoalRevision = state.GoalRevision or 0,
		FailedGoalRevision = nil,
		IsMoving = false,
	}, "Unit")
	self:_MarkDirty(entity)
end

function MovementApplySystem:_SetUnitPresentation(entity: number, animationState: string, isLooping: boolean)
	self._entityFactory:Set(entity, "AnimationState", animationState, "Unit")
	self._entityFactory:Set(entity, "AnimationLooping", isLooping, "Unit")
	self:_MarkDirty(entity)
end

function MovementApplySystem:_WriteApplyResult(
	entity: number,
	requestedAt: number,
	updatedAt: number,
	status: string,
	isMoving: boolean,
	isDone: boolean,
	failureReason: string?
)
	self._entityFactory:Set(entity, "ApplyResult", {
		RequestedAt = requestedAt,
		UpdatedAt = updatedAt,
		Status = status,
		IsMoving = isMoving,
		IsDone = isDone,
		FailureReason = failureReason,
	}, "Movement")
end

function MovementApplySystem:_Get(entity: number, key: string, featureName: string): any
	local result = self._entityFactory:Get(entity, key, featureName)
	return if result.success then result.value else nil
end

function MovementApplySystem:_MarkDirty(entity: number)
	self._entityFactory:Add(entity, "DirtyTag", "Entity")
end

return MovementApplySystem
