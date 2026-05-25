--!strict

--[=[
    @class BuildStructureExecutor
    Drives autonomous builder construction by acquiring one unfinished owned structure, moving into range, and contributing work over time.

    @server
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local BaseExecutor = require(ServerStorage.Utilities.ContextUtilities.BaseExecutor)
local UnitConfig = require(ReplicatedStorage.Contexts.Unit.Config.UnitConfig)

local ACTIVE_MOVEMENT_TARGET_KEY = "ActiveMovementTargetStructureEntity"

local BuildStructureExecutor = {}
BuildStructureExecutor.__index = BuildStructureExecutor
setmetatable(BuildStructureExecutor, BaseExecutor)

function BuildStructureExecutor.new()
	local self = BaseExecutor.new({
		ActionId = "Unit.BuildStructure",
		IsCommitted = false,
		AutoCleanupOnComplete = true,
	})
	return setmetatable(self, BuildStructureExecutor)
end

local function _ResolveMovementMode(services: any, entity: number): (string?, string?)
	local identity = services.UnitEntityFactory:GetIdentity(entity)
	if identity == nil then
		return nil, "MissingIdentity"
	end

	local unitDefinition = UnitConfig.Definitions[identity.UnitId]
	if unitDefinition == nil or unitDefinition.MovementMode == nil then
		return nil, "InvalidMovementMode"
	end

	return unitDefinition.MovementMode, nil
end

local function _ClearMovementState(self: any, entity: number, services: any)
	self:ClearEntityValue(entity, ACTIVE_MOVEMENT_TARGET_KEY)
	if services.MovementService ~= nil then
		services.MovementService:StopMovement(entity)
	end
end

local function _ResolveAssignedStructureEntity(self: any, entity: number, services: any): number?
	local builderConstructionService = services.BuilderConstructionService
	if builderConstructionService == nil then
		return nil
	end

	local assignedStructureEntity = builderConstructionService:GetAssignedStructureEntity(entity)
	if type(assignedStructureEntity) == "number" then
		if builderConstructionService:IsStructureBuildableForBuilder(entity, assignedStructureEntity) then
			return assignedStructureEntity
		end

		builderConstructionService:ClearAssignedStructureEntity(entity)
		_ClearMovementState(self, entity, services)
	end

	local nearestStructureEntity = builderConstructionService:FindNearestOwnedUnfinishedStructure(entity)
	if type(nearestStructureEntity) ~= "number" then
		return nil
	end

	builderConstructionService:SetAssignedStructureEntity(entity, nearestStructureEntity)
	return nearestStructureEntity
end

local function _StartMovementIfNeeded(self: any, entity: number, targetStructureEntity: number, services: any): (boolean, string?)
	if services.MovementService == nil then
		return false, "MissingMovementService"
	end

	local targetPosition = services.BuilderConstructionService:GetStructurePosition(entity, targetStructureEntity)
	if targetPosition == nil then
		return false, "MissingStructurePosition"
	end

	local activeMovementTarget = self:GetEntityValue(entity, ACTIVE_MOVEMENT_TARGET_KEY)
	if activeMovementTarget == targetStructureEntity then
		return true, nil
	end

	local movementMode, movementModeError = _ResolveMovementMode(services, entity)
	if movementMode == nil then
		return false, movementModeError
	end

	local started, reason = services.MovementService:StartAdvance(entity, movementMode, targetPosition)
	if not started then
		return false, if reason ~= nil then reason else "StartAdvanceFailed"
	end

	self:SetEntityValue(entity, ACTIVE_MOVEMENT_TARGET_KEY, targetStructureEntity)
	return true, nil
end

function BuildStructureExecutor:CanStart(entity: number, _data: any?, services: any): (boolean, string?)
	if not services.UnitEntityFactory:IsActive(entity) then
		return false, "InactiveUnit"
	end

	if services.BuilderConstructionService == nil then
		return false, "MissingBuilderConstructionService"
	end

	return true, nil
end

function BuildStructureExecutor:CanContinue(entity: number, services: any): (boolean, string?)
	if not services.UnitEntityFactory:IsActive(entity) then
		return false, "InactiveUnit"
	end

	if services.BuilderConstructionService == nil then
		return false, "MissingBuilderConstructionService"
	end

	return true, nil
end

function BuildStructureExecutor:OnTick(entity: number, dt: number, services: any): string
	local builderConstructionService = services.BuilderConstructionService
	if builderConstructionService == nil then
		return self:Fail(entity, "MissingBuilderConstructionService")
	end

	local targetStructureEntity = _ResolveAssignedStructureEntity(self, entity, services)
	if type(targetStructureEntity) ~= "number" then
		_ClearMovementState(self, entity, services)
		return self:Fail(entity, "MissingBuildTarget")
	end

	if not builderConstructionService:IsStructureBuildableForBuilder(entity, targetStructureEntity) then
		builderConstructionService:ClearAssignedStructureEntity(entity)
		_ClearMovementState(self, entity, services)
		return self:Fail(entity, "InvalidBuildTarget")
	end

	if builderConstructionService:IsBuilderWithinBuildRange(entity, targetStructureEntity) then
		_ClearMovementState(self, entity, services)

		local contributionResult = builderConstructionService:ContributeToStructure(entity, targetStructureEntity, dt)
		if contributionResult == nil or not contributionResult.success then
			builderConstructionService:ClearAssignedStructureEntity(entity)
			return self:Fail(
				entity,
				if contributionResult ~= nil and contributionResult.message ~= nil
					then contributionResult.message
					else "ConstructionContributionFailed"
			)
		end

		if contributionResult.value.Completed then
			builderConstructionService:ClearAssignedStructureEntity(entity)
			return self:Success()
		end

		return self:Running()
	end

	local started, reason = _StartMovementIfNeeded(self, entity, targetStructureEntity, services)
	if not started then
		return self:Fail(entity, if reason ~= nil then reason else "StartAdvanceFailed")
	end

	services.DeltaTime = dt
	local isDone, stepReason = services.MovementService:StepAdvance(entity, services)
	if stepReason ~= nil then
		_ClearMovementState(self, entity, services)
		return self:Fail(entity, stepReason)
	end

	if isDone then
		_ClearMovementState(self, entity, services)
	end

	return self:Running()
end

function BuildStructureExecutor:OnCancel(entity: number, services: any)
	_ClearMovementState(self, entity, services)
end

function BuildStructureExecutor:OnComplete(entity: number, services: any)
	_ClearMovementState(self, entity, services)
end

function BuildStructureExecutor:OnDeath(entity: number, services: any)
	_ClearMovementState(self, entity, services)
end

return BuildStructureExecutor
