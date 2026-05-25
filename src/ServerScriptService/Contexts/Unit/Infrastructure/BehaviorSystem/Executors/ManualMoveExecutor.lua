--!strict

--[=[
    @class ManualMoveExecutor
    Drives manual move actions for units with a valid goal position and active movement state.

    @server
]=]

local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BaseExecutor = require(ServerStorage.Utilities.ContextUtilities.BaseExecutor)
local UnitConfig = require(ReplicatedStorage.Contexts.Unit.Config.UnitConfig)

local START_FAILURE_REASON_KEY = "StartFailureReason"
local ACTIVE_GOAL_REVISION_KEY = "ActiveGoalRevision"

local ManualMoveExecutor = {}
ManualMoveExecutor.__index = ManualMoveExecutor
setmetatable(ManualMoveExecutor, BaseExecutor)

function ManualMoveExecutor.new()
	local self = BaseExecutor.new({
		ActionId = "Unit.ManualMove",
		IsCommitted = false,
		AutoCleanupOnComplete = true,
	})
	return setmetatable(self, ManualMoveExecutor)
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

-- Verifies the unit is active and already has a goal before the manual-move action can begin.
function ManualMoveExecutor:CanStart(entity: number, _data: any?, services: any): (boolean, string?)
	if not services.UnitEntityFactory:IsActive(entity) then
		return false, "InactiveUnit"
	end

	local pathState = services.UnitEntityFactory:GetPathState(entity)
	if pathState == nil or pathState.GoalPosition == nil then
		return false, "MissingGoalPosition"
	end

	return true, nil
end

-- Starts the movement behavior and records a failure reason when the movement service cannot begin advancing.
function ManualMoveExecutor:OnStart(entity: number, _data: any?, services: any)
	local pathState = services.UnitEntityFactory:GetPathState(entity)
	if pathState == nil or pathState.GoalPosition == nil then
		self:SetEntityValue(entity, START_FAILURE_REASON_KEY, "MissingGoalPosition")
		self:ClearEntityValue(entity, ACTIVE_GOAL_REVISION_KEY)
		services.MovementService:StopMovement(entity)
		return
	end

	local movementMode, movementModeError = _ResolveMovementMode(services, entity)
	if movementMode == nil then
		self:SetEntityValue(entity, START_FAILURE_REASON_KEY, movementModeError :: string)
		self:ClearEntityValue(entity, ACTIVE_GOAL_REVISION_KEY)
		services.MovementService:StopMovement(entity)
		return
	end

	local started, reason =
		services.MovementService:StartAdvance(entity, movementMode, pathState.GoalPosition)
	if not started then
		self:SetEntityValue(entity, START_FAILURE_REASON_KEY, if reason ~= nil then reason else "StartAdvanceFailed")
		self:ClearEntityValue(entity, ACTIVE_GOAL_REVISION_KEY)
		services.UnitEntityFactory:MarkGoalFailedCurrentRevision(entity)
		services.MovementService:StopMovement(entity)
		return
	end
	self:ClearEntityValue(entity, START_FAILURE_REASON_KEY)
	self:SetEntityValue(entity, ACTIVE_GOAL_REVISION_KEY, pathState.GoalRevision)
end

-- Continues only while the unit remains active and still has a movement goal.
function ManualMoveExecutor:CanContinue(entity: number, services: any): (boolean, string?)
	if not services.UnitEntityFactory:IsActive(entity) then
		return false, "InactiveUnit"
	end

	local pathState = services.UnitEntityFactory:GetPathState(entity)
	if pathState == nil or pathState.GoalPosition == nil then
		return false, "MissingGoalPosition"
	end

	return true, nil
end

-- Steps the movement service forward until the action succeeds, fails, or remains in progress.
function ManualMoveExecutor:OnTick(entity: number, _dt: number, services: any): string
	local startFailureReason = self:GetEntityValue(entity, START_FAILURE_REASON_KEY)
	if type(startFailureReason) == "string" then
		return self:Fail(entity, startFailureReason)
	end

	local pathState = services.UnitEntityFactory:GetPathState(entity)
	if pathState == nil or pathState.GoalPosition == nil then
		return self:Fail(entity, "MissingGoalPosition")
	end

	local activeGoalRevision = self:GetEntityValue(entity, ACTIVE_GOAL_REVISION_KEY)
	if type(activeGoalRevision) ~= "number" then
		activeGoalRevision = pathState.GoalRevision
		self:SetEntityValue(entity, ACTIVE_GOAL_REVISION_KEY, activeGoalRevision)
	end

	if pathState.GoalRevision ~= activeGoalRevision then
		local movementMode, movementModeError = _ResolveMovementMode(services, entity)
		if movementMode == nil then
			services.UnitEntityFactory:MarkGoalFailedCurrentRevision(entity)
			services.MovementService:StopMovement(entity)
			return self:Fail(entity, movementModeError :: string)
		end

		local started, reason = services.MovementService:StartAdvance(entity, movementMode, pathState.GoalPosition)
		if not started then
			services.UnitEntityFactory:MarkGoalFailedCurrentRevision(entity)
			services.MovementService:StopMovement(entity)
			return self:Fail(entity, if reason ~= nil then reason else "StartAdvanceFailed")
		end

		self:SetEntityValue(entity, ACTIVE_GOAL_REVISION_KEY, pathState.GoalRevision)
	end

	services.DeltaTime = _dt
	local isDone, reason = services.MovementService:StepAdvance(entity, services)
	if reason ~= nil then
		services.UnitEntityFactory:MarkGoalFailedCurrentRevision(entity)
		services.MovementService:StopMovement(entity)
		return self:Fail(entity, reason)
	end
	if isDone then
		return "Success"
	end

	return "Running"
end

-- Stops the movement service without clearing the goal so cancellation can be resumed later.
function ManualMoveExecutor:OnCancel(entity: number, services: any)
	self:ClearEntityValue(entity, START_FAILURE_REASON_KEY)
	self:ClearEntityValue(entity, ACTIVE_GOAL_REVISION_KEY)
	services.MovementService:StopMovement(entity)
end

-- Clears the goal when the action completes successfully and stops the movement service.
function ManualMoveExecutor:OnComplete(entity: number, services: any)
	self:ClearEntityValue(entity, START_FAILURE_REASON_KEY)
	self:ClearEntityValue(entity, ACTIVE_GOAL_REVISION_KEY)
	services.UnitEntityFactory:ClearGoalPosition(entity)
	services.MovementService:StopMovement(entity)
end

-- Stops movement if the unit dies before the action can finish.
function ManualMoveExecutor:OnDeath(entity: number, services: any)
	self:ClearEntityValue(entity, START_FAILURE_REASON_KEY)
	self:ClearEntityValue(entity, ACTIVE_GOAL_REVISION_KEY)
	services.MovementService:StopMovement(entity)
end

return ManualMoveExecutor
