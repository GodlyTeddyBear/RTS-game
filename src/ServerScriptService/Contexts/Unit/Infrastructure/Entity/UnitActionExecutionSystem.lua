--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local AISharedContract = require(ReplicatedStorage.Contexts.AI.AISharedContract)
local ServerScheduler = require(ServerScriptService.Scheduler.ServerScheduler)
local UnitConfig = require(ReplicatedStorage.Contexts.Unit.Config.UnitConfig)

local UnitActionExecutionSystem = {}
UnitActionExecutionSystem.__index = UnitActionExecutionSystem

local ACTION_IDLE = "UnitIdle"
local ACTION_MANUAL_MOVE = "UnitManualMove"
local ACTION_BUILD_STRUCTURE = "UnitBuildStructure"

function UnitActionExecutionSystem.new(entityFactory: any, dependencies: any)
	local self = setmetatable({}, UnitActionExecutionSystem)
	self._entityFactory = entityFactory
	self._entityContext = dependencies.EntityContext
	self._structureContext = dependencies.StructureContext
	self._unitReadService = dependencies.UnitReadService
	self._movementRuntimeService = dependencies.MovementRuntimeService
	return self
end

function UnitActionExecutionSystem:Run()
	-- READS: Unit.Role, Unit.PathState, Unit.BuilderAssignment, Unit.CurrentMoveSpeed, Entity.Transform, Entity.Ownership, AI.ActionState, AI.ActionIntent
	-- WRITES: Unit.PathState, Unit.BuilderAssignment, Unit.AnimationState, Unit.AnimationLooping, Unit.GoalReachedTag, Entity.DirtyTag, Entity.Target
	local queryResult = self._entityFactory:Query({
		FeatureName = "Unit",
		Keys = {
			{ Key = "ActiveTag", FeatureName = "Entity" },
			{ Key = "Role", FeatureName = "Unit" },
			{ Key = "PathState", FeatureName = "Unit" },
		},
	})
	if not queryResult.success then
		return
	end

	local deltaTime = ServerScheduler:GetDeltaTime()
	for _, entity in ipairs(queryResult.value) do
		self:_RunEntity(entity, deltaTime)
	end
end

function UnitActionExecutionSystem:_RunEntity(entity: number, deltaTime: number)
	local actionState = self:_Get(entity, AISharedContract.Components.ActionState, AISharedContract.FeatureName)
	local actionIntent = self:_Get(entity, AISharedContract.Components.ActionIntent, AISharedContract.FeatureName)
	local actionId = if type(actionIntent) == "table" then actionIntent.ActionId else nil

	if type(actionState) ~= "table" or actionState.Status ~= AISharedContract.ActionStatus.Running then
		self:_RunIdle(entity)
		return
	end

	if actionId == ACTION_MANUAL_MOVE then
		self:_RunManualMove(entity, deltaTime)
	elseif actionId == ACTION_BUILD_STRUCTURE then
		self:_RunBuildStructure(entity, deltaTime)
	elseif actionId == ACTION_IDLE then
		self:_RunIdle(entity)
	else
		self:_RunIdle(entity)
	end
end

function UnitActionExecutionSystem:_RunManualMove(entity: number, deltaTime: number)
	self:_ClearBuilderAssignment(entity)
	local pathState = self._unitReadService:GetPathState(entity)
	local goalPosition = if type(pathState) == "table" then pathState.GoalPosition else nil
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

	local started, startReason = self._movementRuntimeService:StartAdvance(entity, movementMode, goalPosition)
	if not started then
		self:_MarkGoalFailedCurrentRevision(entity)
		self._movementRuntimeService:StopMovement(entity)
		self:_SetPathMoving(entity, false)
		self:_SetPresentation(entity, "Idle", true)
		return
	end

	local isDone, stepReason = self._movementRuntimeService:StepAdvance(entity, {
		DeltaTime = deltaTime,
	})
	if stepReason ~= nil then
		self:_MarkGoalFailedCurrentRevision(entity)
		self._movementRuntimeService:StopMovement(entity)
		self:_SetPathMoving(entity, false)
		self:_SetPresentation(entity, "Idle", true)
		return
	end

	self:_SetPathMoving(entity, true)
	self:_SetPresentation(entity, "Walk", true)
	if isDone then
		self:_ClearGoalPosition(entity)
		self._movementRuntimeService:StopMovement(entity)
		self:_SetPresentation(entity, "Idle", true)
	end
end

function UnitActionExecutionSystem:_RunBuildStructure(entity: number, deltaTime: number)
	local targetStructureEntity = self:_ResolveBuildTarget(entity)
	if type(targetStructureEntity) ~= "number" then
		self:_ClearBuilderAssignment(entity)
		self:_RunIdle(entity)
		return
	end

	if self:_IsBuilderWithinBuildRange(entity, targetStructureEntity) then
		self._movementRuntimeService:StopMovement(entity)
		self:_SetPathMoving(entity, false)
		self:_SetPresentation(entity, "Build", true)

		local buildWorkPerSecond = self:_GetBuildWorkPerSecond(entity)
		if buildWorkPerSecond == nil or deltaTime <= 0 then
			return
		end

		local contributionResult = self._structureContext:ContributeConstruction(targetStructureEntity, buildWorkPerSecond * deltaTime, {
			BuilderEntity = entity,
		})
		if not contributionResult.success then
			self:_ClearBuilderAssignment(entity)
			return
		end
		if contributionResult.value.Completed == true then
			self:_ClearBuilderAssignment(entity)
			self:_RunIdle(entity)
		end
		return
	end

	local targetPosition = self:_GetStructurePosition(targetStructureEntity)
	local movementMode = self:_ResolveMovementMode(entity)
	if targetPosition == nil or movementMode == nil then
		self:_ClearBuilderAssignment(entity)
		self:_RunIdle(entity)
		return
	end

	local started = self._movementRuntimeService:StartAdvance(entity, movementMode, targetPosition)
	if not started then
		self:_ClearBuilderAssignment(entity)
		self:_RunIdle(entity)
		return
	end

	local isDone, stepReason = self._movementRuntimeService:StepAdvance(entity, {
		DeltaTime = deltaTime,
	})
	if stepReason ~= nil then
		self:_ClearBuilderAssignment(entity)
		self:_RunIdle(entity)
		return
	end

	self:_SetPathMoving(entity, not isDone)
	self:_SetPresentation(entity, "Walk", true)
end

function UnitActionExecutionSystem:_RunIdle(entity: number)
	self._movementRuntimeService:StopMovement(entity)
	self:_SetPathMoving(entity, false)
	self:_SetPresentation(entity, "Idle", true)
end

function UnitActionExecutionSystem:_ResolveBuildTarget(entity: number): number?
	local assignment = self._unitReadService:GetBuilderAssignment(entity)
	local assignedEntity = if type(assignment) == "table" then assignment.TargetStructureEntity else nil
	if type(assignedEntity) == "number" and self:_IsStructureBuildableForBuilder(entity, assignedEntity) then
		return assignedEntity
	end

	local nearest = self:_FindNearestOwnedUnfinishedStructure(entity)
	if type(nearest) == "number" then
		self:_SetBuilderAssignment(entity, nearest)
		return nearest
	end

	return nil
end

function UnitActionExecutionSystem:_FindNearestOwnedUnfinishedStructure(entity: number): number?
	local ownerUserId = self:_ResolveOwnerUserId(entity)
	local position = self:_GetUnitPosition(entity)
	if ownerUserId == nil or position == nil then
		return nil
	end

	local result = self._structureContext:FindNearestOwnedUnfinishedStructure(ownerUserId, position, math.huge)
	return if result.success then result.value else nil
end

function UnitActionExecutionSystem:_IsBuilderWithinBuildRange(entity: number, structureEntity: number): boolean
	return self:_IsStructureBuildableForBuilder(entity, structureEntity)
end

function UnitActionExecutionSystem:_IsStructureBuildableForBuilder(entity: number, structureEntity: number): boolean
	local ownerUserId = self:_ResolveOwnerUserId(entity)
	local position = self:_GetUnitPosition(entity)
	local buildRange = self:_GetBuildRange(entity)
	if ownerUserId == nil or position == nil or buildRange == nil then
		return false
	end

	local result = self._structureContext:IsStructureBuildableForBuilder(structureEntity, ownerUserId, position, buildRange)
	return result.success and result.value == true
end

function UnitActionExecutionSystem:_ResolveMovementMode(entity: number): string?
	local identity = self._unitReadService:GetIdentity(entity)
	local definition = if type(identity) == "table" then UnitConfig.Definitions[identity.UnitId] else nil
	local movementMode = if definition ~= nil then definition.MovementMode else nil
	return if type(movementMode) == "string" and movementMode ~= "" then movementMode else nil
end

function UnitActionExecutionSystem:_GetBuildWorkPerSecond(entity: number): number?
	local identity = self._unitReadService:GetIdentity(entity)
	local definition = if type(identity) == "table" then UnitConfig.Definitions[identity.UnitId] else nil
	local value = if definition ~= nil then definition.BuildWorkPerSecond else nil
	return if type(value) == "number" and value > 0 then value else nil
end

function UnitActionExecutionSystem:_GetBuildRange(entity: number): number?
	local identity = self._unitReadService:GetIdentity(entity)
	local definition = if type(identity) == "table" then UnitConfig.Definitions[identity.UnitId] else nil
	local value = if definition ~= nil then definition.BuildRange else nil
	return if type(value) == "number" and value > 0 then value else nil
end

function UnitActionExecutionSystem:_ResolveOwnerUserId(entity: number): number?
	local ownership = self._unitReadService:GetOwnership(entity)
	if type(ownership) ~= "table" or ownership.OwnerKind ~= "Player" then
		return nil
	end
	return tonumber(ownership.OwnerId)
end

function UnitActionExecutionSystem:_GetUnitPosition(entity: number): Vector3?
	local cframe = self._unitReadService:GetEntityCFrame(entity)
	return if cframe ~= nil then cframe.Position else nil
end

function UnitActionExecutionSystem:_GetStructurePosition(structureEntity: number): Vector3?
	local result = self._structureContext:GetStructurePosition(structureEntity)
	return if result.success then result.value else nil
end

function UnitActionExecutionSystem:_SetBuilderAssignment(entity: number, targetStructureEntity: number?)
	self._entityFactory:Set(entity, "BuilderAssignment", {
		TargetStructureEntity = targetStructureEntity,
	}, "Unit")
	self:_MarkDirty(entity)
end

function UnitActionExecutionSystem:_ClearBuilderAssignment(entity: number)
	self:_SetBuilderAssignment(entity, nil)
end

function UnitActionExecutionSystem:_SetPathMoving(entity: number, isMoving: boolean)
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

function UnitActionExecutionSystem:_ClearGoalPosition(entity: number)
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

function UnitActionExecutionSystem:_MarkGoalFailedCurrentRevision(entity: number)
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

function UnitActionExecutionSystem:_SetPresentation(entity: number, animationState: string, isLooping: boolean)
	self._entityFactory:Set(entity, "AnimationState", animationState, "Unit")
	self._entityFactory:Set(entity, "AnimationLooping", isLooping, "Unit")
	self:_MarkDirty(entity)
end

function UnitActionExecutionSystem:_Get(entity: number, key: string, featureName: string): any
	local result = self._entityFactory:Get(entity, key, featureName)
	return if result.success then result.value else nil
end

function UnitActionExecutionSystem:_MarkDirty(entity: number)
	self._entityFactory:Add(entity, "DirtyTag", "Entity")
end

return UnitActionExecutionSystem
