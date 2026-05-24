--!strict

local ServerStorage = game:GetService("ServerStorage")

local BaseExecutor = require(ServerStorage.Utilities.ContextUtilities.BaseExecutor)

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

function ManualMoveExecutor:CanStart(entity: number, _data: any?, services: any): (boolean, string?)
	--print("can start manual move")
	if not services.UnitEntityFactory:IsActive(entity) then
		return false, "InactiveUnit"
	end

	local pathState = services.UnitEntityFactory:GetPathState(entity)
	--print("Get path state", pathState)
	if pathState == nil or pathState.GoalPosition == nil then
		return false, "MissingGoalPosition"
	end

	return true, nil
end

function ManualMoveExecutor:OnStart(entity: number, _data: any?, services: any)
	local started, reason = services.MovementService:StartUnitMove(entity)
	if not started then
		self:SetEntityValue(entity, START_FAILURE_REASON_KEY, if reason ~= nil then reason else "StartUnitMoveFailed")
		services.MovementService:StopUnitMovement(entity)
		return
	end

	self:ClearEntityValue(entity, START_FAILURE_REASON_KEY)
end

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

function ManualMoveExecutor:OnTick(entity: number, _dt: number, services: any): string
	local startFailureReason = self:GetEntityValue(entity, START_FAILURE_REASON_KEY)
	if type(startFailureReason) == "string" then
		return self:Fail(entity, startFailureReason)
	end

	local isDone, reason = services.MovementService:StepUnitMove(entity)
	if reason ~= nil then
		return self:Fail(entity, reason)
	end
	if isDone then
		return "Success"
	end

	return "Running"
end

function ManualMoveExecutor:OnCancel(entity: number, services: any)
	self:ClearEntityValue(entity, START_FAILURE_REASON_KEY)
	services.MovementService:StopUnitMovement(entity)
end

function ManualMoveExecutor:OnComplete(entity: number, services: any)
	self:ClearEntityValue(entity, START_FAILURE_REASON_KEY)
	services.UnitEntityFactory:ClearGoalPosition(entity)
	services.MovementService:StopUnitMovement(entity)
end

function ManualMoveExecutor:OnDeath(entity: number, services: any)
	self:ClearEntityValue(entity, START_FAILURE_REASON_KEY)
	services.MovementService:StopUnitMovement(entity)
end

return ManualMoveExecutor
