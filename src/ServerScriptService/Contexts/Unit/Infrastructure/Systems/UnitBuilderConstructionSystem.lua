--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local AISharedContract = require(ReplicatedStorage.Contexts.AI.AISharedContract)
local ServerScheduler = require(ServerScriptService.Scheduler.ServerScheduler)
local UnitConfig = require(ReplicatedStorage.Contexts.Unit.Config.UnitConfig)

local UnitBuilderConstructionSystem = {}
UnitBuilderConstructionSystem.__index = UnitBuilderConstructionSystem

local ACTION_BUILD_STRUCTURE = "BuildStructure"

function UnitBuilderConstructionSystem.new(entityFactory: any, dependencies: any)
	local self = setmetatable({}, UnitBuilderConstructionSystem)
	self._entityFactory = entityFactory
	self._structureContext = dependencies.StructureContext
	self._unitReadService = dependencies.UnitReadService
	return self
end

function UnitBuilderConstructionSystem:Run()
	-- READS: Structure.BuildContributionState, Unit.BuilderAssignment, Entity.Ownership, AI.ActionState
	-- WRITES: Unit.BuilderAssignment, Movement.MoveIntent, Entity.DirtyTag
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

function UnitBuilderConstructionSystem:_RunBuilder(builderEntity: number, deltaTime: number)
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

	if self:_IsStructureBuildableForBuilder(builderEntity, targetStructureEntity) then
		self:_ClearMoveIntent(builderEntity)

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

	self:_SetMoveIntent(builderEntity, targetPosition, movementMode)
end

function UnitBuilderConstructionSystem:_ResolveBuildTarget(builderEntity: number): number?
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

function UnitBuilderConstructionSystem:_FindNearestOwnedUnfinishedStructure(builderEntity: number): number?
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

function UnitBuilderConstructionSystem:_IsStructureBuildableForBuilder(builderEntity: number, structureEntity: number): boolean
	local ownerUserId = self:_ResolveOwnerUserId(builderEntity)
	local position = self:_GetUnitPosition(builderEntity)
	local buildRange = self:_GetBuildRange(builderEntity)
	if ownerUserId == nil or position == nil or buildRange == nil then
		return false
	end

	local result = self._structureContext:IsStructureBuildableForBuilder(structureEntity, ownerUserId, position, buildRange)
	return result.success and result.value == true
end

function UnitBuilderConstructionSystem:_RunIdle(entity: number)
	self:_ClearMoveIntent(entity)
end

function UnitBuilderConstructionSystem:_ResolveMovementMode(entity: number): string?
	local identity = self._unitReadService:GetIdentity(entity)
	local definition = if type(identity) == "table" then UnitConfig.Definitions[identity.UnitId] else nil
	local movementMode = if definition ~= nil then definition.Movement.Mode else nil
	return if type(movementMode) == "string" and movementMode ~= "" then movementMode else nil
end

function UnitBuilderConstructionSystem:_GetBuildWorkPerSecond(entity: number): number?
	local identity = self._unitReadService:GetIdentity(entity)
	local definition = if type(identity) == "table" then UnitConfig.Definitions[identity.UnitId] else nil
	local build = if definition ~= nil then definition.Capabilities.Build else nil
	local value = if build ~= nil then build.WorkPerSecond else nil
	return if type(value) == "number" and value > 0 then value else nil
end

function UnitBuilderConstructionSystem:_GetBuildRange(entity: number): number?
	local identity = self._unitReadService:GetIdentity(entity)
	local definition = if type(identity) == "table" then UnitConfig.Definitions[identity.UnitId] else nil
	local build = if definition ~= nil then definition.Capabilities.Build else nil
	local value = if build ~= nil then build.Range else nil
	return if type(value) == "number" and value > 0 then value else nil
end

function UnitBuilderConstructionSystem:_ResolveOwnerUserId(entity: number): number?
	local ownership = self._unitReadService:GetOwnership(entity)
	if type(ownership) ~= "table" or ownership.OwnerKind ~= "Player" then
		return nil
	end
	return tonumber(ownership.OwnerId)
end

function UnitBuilderConstructionSystem:_GetUnitPosition(entity: number): Vector3?
	local cframe = self._unitReadService:GetEntityCFrame(entity)
	return if cframe ~= nil then cframe.Position else nil
end

function UnitBuilderConstructionSystem:_GetStructurePosition(structureEntity: number): Vector3?
	local result = self._structureContext:GetStructurePosition(structureEntity)
	return if result.success then result.value else nil
end

function UnitBuilderConstructionSystem:_SetBuilderAssignment(entity: number, targetStructureEntity: number?)
	self._entityFactory:Set(entity, "BuilderAssignment", {
		TargetStructureEntity = targetStructureEntity,
	}, "Unit")
	self:_MarkDirty(entity)
end

function UnitBuilderConstructionSystem:_SetMoveIntent(entity: number, goalPosition: Vector3, movementMode: string)
	self._entityFactory:Set(entity, "MoveIntent", {
		SourceEntity = entity,
		GoalPosition = goalPosition,
		MovementMode = movementMode,
		ActionId = ACTION_BUILD_STRUCTURE,
		Reason = "BuildStructure",
		RequestedAt = os.clock(),
		Status = "Requested",
	}, "Movement")
	self:_MarkDirty(entity)
end

function UnitBuilderConstructionSystem:_ClearMoveIntent(entity: number)
	self._entityFactory:Remove(entity, "MoveIntent", "Movement")
	self:_MarkDirty(entity)
end

function UnitBuilderConstructionSystem:_Get(entity: number, key: string, featureName: string): any
	local result = self._entityFactory:Get(entity, key, featureName)
	return if result.success then result.value else nil
end

function UnitBuilderConstructionSystem:_MarkDirty(entity: number)
	self._entityFactory:Add(entity, "DirtyTag", "Entity")
end

return UnitBuilderConstructionSystem
