--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local AISharedContract = require(ReplicatedStorage.Contexts.AI.AISharedContract)
local ServerScheduler = require(ServerScriptService.Scheduler.ServerScheduler)
local UnitConfig = require(ReplicatedStorage.Contexts.Unit.Config.UnitConfig)

local StructureBuildContributionSystem = {}
StructureBuildContributionSystem.__index = StructureBuildContributionSystem

local ACTION_BUILD_STRUCTURE = "BuildStructure"

function StructureBuildContributionSystem.new(entityFactory: any, dependencies: any)
	local self = setmetatable({}, StructureBuildContributionSystem)
	self._entityFactory = entityFactory
	self._structureContext = dependencies.StructureContext
	self._unitReadService = dependencies.UnitReadService
	self._movementRuntimeService = dependencies.MovementRuntimeService
	return self
end

function StructureBuildContributionSystem:Run()
	-- READS: Structure.BuildContributionState [AUTHORITATIVE], Unit.BuilderAssignment [AUTHORITATIVE], Unit.PathState [AUTHORITATIVE], Entity.Ownership [AUTHORITATIVE], AI.ActionState [AUTHORITATIVE]
	-- WRITES: Unit.BuilderAssignment [AUTHORITATIVE], Unit.PathState [AUTHORITATIVE], Unit.AnimationState [DERIVED], Unit.AnimationLooping [DERIVED], Entity.DirtyTag
	local queryResult = self._entityFactory:Query({
		FeatureName = "Structure",
		Keys = { "BuildContributionState" },
	})
	if not queryResult.success then
		return
	end

	local deltaTime = ServerScheduler:GetDeltaTime()
	for _, builderEntity in ipairs(queryResult.value) do
		self:_RunBuilder(builderEntity, deltaTime)
	end
end

function StructureBuildContributionSystem:_RunBuilder(builderEntity: number, deltaTime: number)
	local actionState = self:_Get(builderEntity, AISharedContract.Components.ActionState, AISharedContract.FeatureName)
	if type(actionState) ~= "table" or actionState.ActionId ~= ACTION_BUILD_STRUCTURE then
		if type(actionState) == "table" and actionState.ActionId == "Idle" then
			self:_RunIdle(builderEntity)
		end
		return
	end

	local targetStructureEntity = self:_ResolveBuildTarget(builderEntity)
	if type(targetStructureEntity) ~= "number" then
		self:_SetBuilderAssignment(builderEntity, nil)
		self:_RunIdle(builderEntity)
		return
	end

	if self:_IsBuilderWithinBuildRange(builderEntity, targetStructureEntity) then
		self._movementRuntimeService:StopMovement(builderEntity)
		self:_SetPathMoving(builderEntity, false)
		self:_SetPresentation(builderEntity, "Build", true)

		local buildWorkPerSecond = self:_GetBuildWorkPerSecond(builderEntity)
		if buildWorkPerSecond == nil or deltaTime <= 0 then
			return
		end

		local contributionResult = self._structureContext:ContributeConstruction(targetStructureEntity, buildWorkPerSecond * deltaTime, {
			BuilderEntity = builderEntity,
		})
		if not contributionResult.success then
			self:_SetBuilderAssignment(builderEntity, nil)
			return
		end
		if contributionResult.value.Completed == true then
			self:_SetBuilderAssignment(builderEntity, nil)
			self:_RunIdle(builderEntity)
		end
		return
	end

	local targetPosition = self:_GetStructurePosition(targetStructureEntity)
	local movementMode = self:_ResolveMovementMode(builderEntity)
	if targetPosition == nil or movementMode == nil then
		self:_SetBuilderAssignment(builderEntity, nil)
		self:_RunIdle(builderEntity)
		return
	end

	local started = self._movementRuntimeService:StartAdvance(builderEntity, movementMode, targetPosition)
	if not started then
		self:_SetBuilderAssignment(builderEntity, nil)
		self:_RunIdle(builderEntity)
		return
	end

	local isDone, stepReason = self._movementRuntimeService:StepAdvance(builderEntity, {
		DeltaTime = deltaTime,
	})
	if stepReason ~= nil then
		self:_SetBuilderAssignment(builderEntity, nil)
		self:_RunIdle(builderEntity)
		return
	end

	self:_SetPathMoving(builderEntity, not isDone)
	self:_SetPresentation(builderEntity, "Walk", true)
end

function StructureBuildContributionSystem:_ResolveBuildTarget(builderEntity: number): number?
	local buildState = self:_Get(builderEntity, "BuildContributionState", "Structure")
	local targetStructureEntity = if type(buildState) == "table" then buildState.TargetStructureEntity else nil
	if type(targetStructureEntity) == "number" and self:_IsStructureBuildableForBuilder(builderEntity, targetStructureEntity) then
		self:_SetBuilderAssignment(builderEntity, targetStructureEntity)
		return targetStructureEntity
	end

	local assignment = self._unitReadService:GetBuilderAssignment(builderEntity)
	local assignedEntity = if type(assignment) == "table" then assignment.TargetStructureEntity else nil
	if type(assignedEntity) == "number" and self:_IsStructureBuildableForBuilder(builderEntity, assignedEntity) then
		return assignedEntity
	end

	return self:_FindNearestOwnedUnfinishedStructure(builderEntity)
end

function StructureBuildContributionSystem:_FindNearestOwnedUnfinishedStructure(builderEntity: number): number?
	local ownerUserId = self:_ResolveOwnerUserId(builderEntity)
	local position = self:_GetUnitPosition(builderEntity)
	if ownerUserId == nil or position == nil then
		return nil
	end

	local result = self._structureContext:FindNearestOwnedUnfinishedStructure(ownerUserId, position, math.huge)
	local entity = if result.success then result.value else nil
	if type(entity) == "number" then
		self:_SetBuilderAssignment(builderEntity, entity)
		return entity
	end
	return nil
end

function StructureBuildContributionSystem:_IsBuilderWithinBuildRange(builderEntity: number, structureEntity: number): boolean
	return self:_IsStructureBuildableForBuilder(builderEntity, structureEntity)
end

function StructureBuildContributionSystem:_IsStructureBuildableForBuilder(builderEntity: number, structureEntity: number): boolean
	local ownerUserId = self:_ResolveOwnerUserId(builderEntity)
	local position = self:_GetUnitPosition(builderEntity)
	local buildRange = self:_GetBuildRange(builderEntity)
	if ownerUserId == nil or position == nil or buildRange == nil then
		return false
	end

	local result = self._structureContext:IsStructureBuildableForBuilder(structureEntity, ownerUserId, position, buildRange)
	return result.success and result.value == true
end

function StructureBuildContributionSystem:_RunIdle(entity: number)
	self._movementRuntimeService:StopMovement(entity)
	self:_SetPathMoving(entity, false)
	self:_SetPresentation(entity, "Idle", true)
end

function StructureBuildContributionSystem:_ResolveMovementMode(entity: number): string?
	local identity = self._unitReadService:GetIdentity(entity)
	local definition = if type(identity) == "table" then UnitConfig.Definitions[identity.UnitId] else nil
	local movementMode = if definition ~= nil then definition.MovementMode else nil
	return if type(movementMode) == "string" and movementMode ~= "" then movementMode else nil
end

function StructureBuildContributionSystem:_GetBuildWorkPerSecond(entity: number): number?
	local identity = self._unitReadService:GetIdentity(entity)
	local definition = if type(identity) == "table" then UnitConfig.Definitions[identity.UnitId] else nil
	local value = if definition ~= nil then definition.BuildWorkPerSecond else nil
	return if type(value) == "number" and value > 0 then value else nil
end

function StructureBuildContributionSystem:_GetBuildRange(entity: number): number?
	local identity = self._unitReadService:GetIdentity(entity)
	local definition = if type(identity) == "table" then UnitConfig.Definitions[identity.UnitId] else nil
	local value = if definition ~= nil then definition.BuildRange else nil
	return if type(value) == "number" and value > 0 then value else nil
end

function StructureBuildContributionSystem:_ResolveOwnerUserId(entity: number): number?
	local ownership = self._unitReadService:GetOwnership(entity)
	if type(ownership) ~= "table" or ownership.OwnerKind ~= "Player" then
		return nil
	end
	return tonumber(ownership.OwnerId)
end

function StructureBuildContributionSystem:_GetUnitPosition(entity: number): Vector3?
	local cframe = self._unitReadService:GetEntityCFrame(entity)
	return if cframe ~= nil then cframe.Position else nil
end

function StructureBuildContributionSystem:_GetStructurePosition(structureEntity: number): Vector3?
	local result = self._structureContext:GetStructurePosition(structureEntity)
	return if result.success then result.value else nil
end

function StructureBuildContributionSystem:_SetBuilderAssignment(entity: number, targetStructureEntity: number?)
	self._entityFactory:Set(entity, "BuilderAssignment", {
		TargetStructureEntity = targetStructureEntity,
	}, "Unit")
	self:_MarkDirty(entity)
end

function StructureBuildContributionSystem:_SetPathMoving(entity: number, isMoving: boolean)
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

function StructureBuildContributionSystem:_SetPresentation(entity: number, animationState: string, isLooping: boolean)
	self._entityFactory:Set(entity, "AnimationState", animationState, "Unit")
	self._entityFactory:Set(entity, "AnimationLooping", isLooping, "Unit")
	self:_MarkDirty(entity)
end

function StructureBuildContributionSystem:_Get(entity: number, key: string, featureName: string): any
	local result = self._entityFactory:Get(entity, key, featureName)
	return if result.success then result.value else nil
end

function StructureBuildContributionSystem:_MarkDirty(entity: number)
	self._entityFactory:Add(entity, "DirtyTag", "Entity")
end

return StructureBuildContributionSystem
