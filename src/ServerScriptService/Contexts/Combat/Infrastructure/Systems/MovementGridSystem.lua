--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AISharedContract = require(ReplicatedStorage.Contexts.AI.AISharedContract)
local UnitConfig = require(ReplicatedStorage.Contexts.Unit.Config.UnitConfig)

local MovementGridSystem = {}
MovementGridSystem.__index = MovementGridSystem

function MovementGridSystem.new(entityFactory: any, dependencies: any)
	local self = setmetatable({}, MovementGridSystem)
	self._entityFactory = entityFactory
	self._movementRuntimeSupport = dependencies.MovementRuntimeSupport
	self._movementService = dependencies.MovementService
	self._worldContext = dependencies.WorldContext
	return self
end

function MovementGridSystem:Run()
	-- READS: Unit.PathState [AUTHORITATIVE], Entity.Identity [AUTHORITATIVE], AI.ActionState [AUTHORITATIVE], Movement.MoveIntent [AUTHORITATIVE]
	-- WRITES: Movement.MoveIntent [AUTHORITATIVE], Movement.FlowGridState [AUTHORITATIVE]
	self:_DeriveUnitMoveIntents()

	local queryResult = self._entityFactory:Query({
		FeatureName = "Movement",
		Keys = { "MoveIntent" },
	})
	if not queryResult.success or #queryResult.value == 0 then
		return
	end

	local isReady, revision = self._movementRuntimeSupport:EnsureFastFlowConfigured(
		self._worldContext,
		self._movementService
	)
	local now = os.clock()
	for _, entity in ipairs(queryResult.value) do
		self._entityFactory:Set(entity, "FlowGridState", {
			Revision = revision,
			Ready = isReady,
			UpdatedAt = now,
			FailureReason = if isReady then nil else "FastFlowGridUnavailable",
		}, "Movement")
	end
end

function MovementGridSystem:_DeriveUnitMoveIntents()
	local queryResult = self._entityFactory:Query({
		FeatureName = "Unit",
		Keys = { "PathState", "Role" },
	})
	if not queryResult.success then
		return
	end

	local now = os.clock()
	for _, entity in ipairs(queryResult.value) do
		local actionState = self:_Get(entity, AISharedContract.Components.ActionState, AISharedContract.FeatureName)
		local actionId = if type(actionState) == "table" then actionState.ActionId else nil
		if self:_ClearTerminalMoveIntent(entity) then
			continue
		end

		if actionId ~= "ManualMove" and actionId ~= "BuildStructure" then
			self:_CancelExistingMoveIntent(entity, now, "InactiveMovementAction")
			continue
		end

		local pathState = self:_Get(entity, "PathState", "Unit")
		local goalPosition = if type(pathState) == "table" then pathState.GoalPosition else nil
		if typeof(goalPosition) ~= "Vector3" then
			self:_CancelExistingMoveIntent(entity, now, "MissingGoalPosition")
			continue
		end

		local movementMode = self:_ResolveUnitMovementMode(entity)
		if movementMode == nil then
			self:_CancelExistingMoveIntent(entity, now, "MissingMovementMode")
			continue
		end

		self._entityFactory:Set(entity, "MoveIntent", {
			SourceEntity = entity,
			GoalPosition = goalPosition,
			MovementMode = movementMode,
			ActionId = actionId,
			Reason = if actionId == "BuildStructure" then "StructureBuildContribution" else "UnitManualMove",
			RequestedAt = now,
			Status = "Requested",
		}, "Movement")
	end
end

function MovementGridSystem:_ClearTerminalMoveIntent(entity: number): boolean
	local existing = self:_Get(entity, "MoveIntent", "Movement")
	if type(existing) ~= "table" then
		return false
	end

	local applyResult = self:_Get(entity, "ApplyResult", "Movement")
	local status = if type(applyResult) == "table" then applyResult.Status else nil
	if status ~= "Done" and status ~= "Failed" and status ~= "Cancelled" then
		return false
	end

	if applyResult.RequestedAt ~= existing.RequestedAt then
		return false
	end

	self._entityFactory:Remove(entity, "MoveIntent", "Movement")
	return true
end

function MovementGridSystem:_CancelExistingMoveIntent(entity: number, now: number, reason: string)
	local existing = self:_Get(entity, "MoveIntent", "Movement")
	if type(existing) ~= "table" then
		return
	end

	self._entityFactory:Set(entity, "MoveIntent", {
		SourceEntity = entity,
		GoalPosition = existing.GoalPosition,
		MovementMode = existing.MovementMode,
		ActionId = existing.ActionId,
		Reason = reason,
		RequestedAt = if type(existing.RequestedAt) == "number" then existing.RequestedAt else now,
		Status = "Cancelled",
	}, "Movement")
end

function MovementGridSystem:_ResolveUnitMovementMode(entity: number): string?
	local identity = self:_Get(entity, "Identity", "Entity")
	local definitionId = if type(identity) == "table" then identity.DefinitionId else nil
	local definition = if type(definitionId) == "string" then UnitConfig.Definitions[definitionId] else nil
	local movementMode = if definition ~= nil then definition.MovementMode else nil
	return if type(movementMode) == "string" and movementMode ~= "" then movementMode else nil
end

function MovementGridSystem:_Get(entity: number, key: string, featureName: string): any
	local result = self._entityFactory:Get(entity, key, featureName)
	return if result.success then result.value else nil
end

return MovementGridSystem
