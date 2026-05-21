--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local BaseExecutor = require(ServerStorage.Utilities.ContextUtilities.BaseExecutor)
local EnemyConfig = require(ReplicatedStorage.Contexts.Enemy.Config.EnemyConfig)
local Result = require(ReplicatedStorage.Utilities.Result)

local START_FAILURE_REASON_KEY = "StartFailureReason"

--[=[
	@class AdvanceExecutor
	Drives enemy movement toward the current base goal.
	@server
]=]
local AdvanceExecutor = {}
AdvanceExecutor.__index = AdvanceExecutor
setmetatable(AdvanceExecutor, BaseExecutor)

function AdvanceExecutor.new()
	local self = BaseExecutor.new({
		ActionId = "Advance",
		IsCommitted = false,
		AutoCleanupOnComplete = true,
	})
	return setmetatable(self, AdvanceExecutor)
end

function AdvanceExecutor:CanStart(entity: number, _data: any?, services: any): (boolean, string?)
	local pathState = services.EnemyEntityFactory:GetPathState(entity)
	if pathState == nil or pathState.GoalPosition == nil then
		return false, "MissingGoalPosition"
	end

	local role = services.EnemyEntityFactory:GetRole(entity)
	if role == nil then
		return false, "MissingRole"
	end

	local roleConfig = EnemyConfig.Roles[role.Role]
	if roleConfig == nil or roleConfig.MovementMode == nil then
		return false, "InvalidMovementMode"
	end

	return true, nil
end

function AdvanceExecutor:OnStart(entity: number, _data: any?, services: any)
	local role = services.EnemyEntityFactory:GetRole(entity)
	if role == nil then
		self:SetEntityValue(entity, START_FAILURE_REASON_KEY, "MissingRole")
		services.MovementService:StopMovement(entity)
		return
	end

	local roleConfig = EnemyConfig.Roles[role.Role]
	if roleConfig == nil or roleConfig.MovementMode == nil then
		self:SetEntityValue(entity, START_FAILURE_REASON_KEY, "InvalidMovementMode")
		services.MovementService:StopMovement(entity)
		return
	end

	local started, reason = services.MovementService:StartAdvance(entity, roleConfig.MovementMode)
	if not started then
		self:SetEntityValue(entity, START_FAILURE_REASON_KEY, if reason ~= nil then reason else "StartAdvanceFailed")
		services.MovementService:StopMovement(entity)
		return
	end
	self:ClearEntityValue(entity, START_FAILURE_REASON_KEY)
end

function AdvanceExecutor:CanContinue(entity: number, services: any): (boolean, string?)
	local pathState = services.EnemyEntityFactory:GetPathState(entity)
	if pathState == nil then
		return false, "MissingPathState"
	end

	if pathState.GoalPosition == nil then
		return false, "MissingGoalPosition"
	end

	return true, nil
end

function AdvanceExecutor:OnTick(entity: number, _dt: number, services: any): string
	local startFailureReason = self:GetEntityValue(entity, START_FAILURE_REASON_KEY)
	if type(startFailureReason) == "string" then
		return self:Fail(entity, startFailureReason)
	end

	services.DeltaTime = _dt
	local isDone, reason = services.MovementService:StepAdvance(entity, services)
	if reason ~= nil then
		return self:Fail(entity, reason)
	end
	if isDone then
		return "Success"
	end
	return "Running"
end

function AdvanceExecutor:OnCancel(entity: number, services: any)
	self:ClearEntityValue(entity, START_FAILURE_REASON_KEY)
	services.MovementService:StopMovement(entity)
end

function AdvanceExecutor:OnComplete(entity: number, services: any)
	self:ClearEntityValue(entity, START_FAILURE_REASON_KEY)
	services.MovementService:StopMovement(entity)

	local enemyContext = services.EnemyContext
	if enemyContext == nil or type(enemyContext.HandleGoalReached) ~= "function" then
		return
	end

	local goalReachedResult = enemyContext:HandleGoalReached(entity)
	if not goalReachedResult.success then
		Result.MentionError("Enemy:AdvanceExecutor", "Failed to handle enemy goal reach", {
			Entity = entity,
			CauseType = goalReachedResult.type,
			CauseMessage = goalReachedResult.message,
		}, goalReachedResult.type)
	end
end

function AdvanceExecutor:OnDeath(entity: number, services: any)
	self:ClearEntityValue(entity, START_FAILURE_REASON_KEY)
	services.MovementService:StopMovement(entity)
end

return AdvanceExecutor
