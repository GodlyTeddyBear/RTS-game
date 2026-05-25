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
		services.MovementService:StopMovement(entity)
		return
	end

	local identity = services.UnitEntityFactory:GetIdentity(entity)
	if identity == nil then
		self:SetEntityValue(entity, START_FAILURE_REASON_KEY, "MissingIdentity")
		services.MovementService:StopMovement(entity)
		return
	end

	local unitDefinition = UnitConfig.Definitions[identity.UnitId]
	if unitDefinition == nil or unitDefinition.MovementMode == nil then
		self:SetEntityValue(entity, START_FAILURE_REASON_KEY, "InvalidMovementMode")
		services.MovementService:StopMovement(entity)
		return
	end

	local started, reason =
		services.MovementService:StartAdvance(entity, unitDefinition.MovementMode, pathState.GoalPosition)
	if not started then
		self:SetEntityValue(entity, START_FAILURE_REASON_KEY, if reason ~= nil then reason else "StartAdvanceFailed")
		services.UnitEntityFactory:MarkGoalFailedCurrentRevision(entity)
		services.MovementService:StopMovement(entity)
		return
	end
	self:ClearEntityValue(entity, START_FAILURE_REASON_KEY)
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
	services.MovementService:StopMovement(entity)
end

-- Clears the goal when the action completes successfully and stops the movement service.
function ManualMoveExecutor:OnComplete(entity: number, services: any)
	self:ClearEntityValue(entity, START_FAILURE_REASON_KEY)
	services.UnitEntityFactory:ClearGoalPosition(entity)
	services.MovementService:StopMovement(entity)
end

-- Stops movement if the unit dies before the action can finish.
function ManualMoveExecutor:OnDeath(entity: number, services: any)
	self:ClearEntityValue(entity, START_FAILURE_REASON_KEY)
	services.MovementService:StopMovement(entity)
end

return ManualMoveExecutor
