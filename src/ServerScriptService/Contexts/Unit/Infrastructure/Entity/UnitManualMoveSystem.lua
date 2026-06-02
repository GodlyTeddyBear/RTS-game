--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AISharedContract = require(ReplicatedStorage.Contexts.AI.AISharedContract)
local UnitConfig = require(ReplicatedStorage.Contexts.Unit.Config.UnitConfig)

local UnitManualMoveSystem = {}
UnitManualMoveSystem.__index = UnitManualMoveSystem

local ACTION_MANUAL_MOVE = "ManualMove"

function UnitManualMoveSystem.new(entityFactory: any, dependencies: any)
	local self = setmetatable({}, UnitManualMoveSystem)
	self._entityFactory = entityFactory
	self._unitReadService = dependencies.UnitReadService
	return self
end

function UnitManualMoveSystem:Run()
	-- READS: Unit.ManualMoveState [AUTHORITATIVE], Unit.PathState [AUTHORITATIVE], Unit.Role [AUTHORITATIVE], AI.ActionState [AUTHORITATIVE]
	-- WRITES: Unit.PathState [AUTHORITATIVE], Unit.BuilderAssignment [AUTHORITATIVE], Unit.AnimationState [DERIVED], Unit.AnimationLooping [DERIVED], Entity.DirtyTag
	local queryResult = self._entityFactory:Query({
		FeatureName = "Unit",
		Keys = { "ManualMoveState", "PathState", "Role" },
	})
	if not queryResult.success then
		return
	end

	for _, entity in ipairs(queryResult.value) do
		self:_RunEntity(entity)
	end
end

function UnitManualMoveSystem:_RunEntity(entity: number)
	local actionState = self:_Get(entity, AISharedContract.Components.ActionState, AISharedContract.FeatureName)
	if type(actionState) ~= "table" or actionState.ActionId ~= ACTION_MANUAL_MOVE then
		if type(actionState) == "table" and actionState.ActionId == "Idle" then
			self:_RunIdle(entity)
		end
		return
	end

	self:_SetBuilderAssignment(entity, nil)
	local moveState = self:_Get(entity, "ManualMoveState", "Unit")
	local goalPosition = if type(moveState) == "table" then moveState.GoalPosition else nil
	if typeof(goalPosition) ~= "Vector3" then
		self:_RunIdle(entity)
		return
	end

	local movementMode = self:_ResolveMovementMode(entity)
	if movementMode == nil then
		self:_MarkGoalFailedCurrentRevision(entity)
		self:_RunIdle(entity)
		return
	end

	self:_SetPathGoal(entity, goalPosition)
	self:_SetPathMoving(entity, true)
	self:_SetPresentation(entity, "Walk", true)
end

function UnitManualMoveSystem:_RunIdle(entity: number)
	self:_SetPathMoving(entity, false)
	self:_SetPresentation(entity, "Idle", true)
end

function UnitManualMoveSystem:_ResolveMovementMode(entity: number): string?
	local identity = self._unitReadService:GetIdentity(entity)
	local definition = if type(identity) == "table" then UnitConfig.Definitions[identity.UnitId] else nil
	local movementMode = if definition ~= nil then definition.MovementMode else nil
	return if type(movementMode) == "string" and movementMode ~= "" then movementMode else nil
end

function UnitManualMoveSystem:_SetBuilderAssignment(entity: number, targetStructureEntity: number?)
	self._entityFactory:Set(entity, "BuilderAssignment", {
		TargetStructureEntity = targetStructureEntity,
	}, "Unit")
	self:_MarkDirty(entity)
end

function UnitManualMoveSystem:_SetPathMoving(entity: number, isMoving: boolean)
	local state = self._unitReadService:GetPathState(entity) or {}
	self._entityFactory:Set(entity, "PathState", {
		GoalPosition = state.GoalPosition,
		RequestedGoalPosition = state.RequestedGoalPosition,
		GoalRevision = state.GoalRevision or 0,
		FailedGoalRevision = state.FailedGoalRevision,
		IsMoving = isMoving,
	}, "Unit")
	self:_MarkDirty(entity)
end

function UnitManualMoveSystem:_SetPathGoal(entity: number, goalPosition: Vector3)
	local state = self._unitReadService:GetPathState(entity) or {}
	self._entityFactory:Set(entity, "PathState", {
		GoalPosition = goalPosition,
		RequestedGoalPosition = state.RequestedGoalPosition or goalPosition,
		GoalRevision = state.GoalRevision or 0,
		FailedGoalRevision = state.FailedGoalRevision,
		IsMoving = true,
	}, "Unit")
	self:_MarkDirty(entity)
end

function UnitManualMoveSystem:_ClearGoalPosition(entity: number)
	local state = self._unitReadService:GetPathState(entity) or {}
	self._entityFactory:Set(entity, "PathState", {
		GoalPosition = nil,
		RequestedGoalPosition = nil,
		GoalRevision = state.GoalRevision or 0,
		FailedGoalRevision = nil,
		IsMoving = false,
	}, "Unit")
	self:_MarkDirty(entity)
end

function UnitManualMoveSystem:_MarkGoalFailedCurrentRevision(entity: number)
	local state = self._unitReadService:GetPathState(entity)
	if type(state) ~= "table" or state.GoalPosition == nil then
		return
	end

	self._entityFactory:Set(entity, "PathState", {
		GoalPosition = state.GoalPosition,
		RequestedGoalPosition = state.RequestedGoalPosition,
		GoalRevision = state.GoalRevision or 0,
		FailedGoalRevision = state.GoalRevision or 0,
		IsMoving = false,
	}, "Unit")
	self:_MarkDirty(entity)
end

function UnitManualMoveSystem:_SetPresentation(entity: number, animationState: string, isLooping: boolean)
	self._entityFactory:Set(entity, "AnimationState", animationState, "Unit")
	self._entityFactory:Set(entity, "AnimationLooping", isLooping, "Unit")
	self:_MarkDirty(entity)
end

function UnitManualMoveSystem:_Get(entity: number, key: string, featureName: string): any
	local result = self._entityFactory:Get(entity, key, featureName)
	return if result.success then result.value else nil
end

function UnitManualMoveSystem:_MarkDirty(entity: number)
	self._entityFactory:Add(entity, "DirtyTag", "Entity")
end

return UnitManualMoveSystem
