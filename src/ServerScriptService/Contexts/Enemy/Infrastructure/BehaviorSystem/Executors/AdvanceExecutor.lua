--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BaseExecutor = require(ReplicatedStorage.Utilities.BaseExecutor)
local EnemyConfig = require(ReplicatedStorage.Contexts.Enemy.Config.EnemyConfig)

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

	return services.MovementService:StartAdvance(entity, roleConfig.MovementMode)
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
	local status, reason = services.MovementService:TickAdvance(entity)
	if status == "Running" then
		return self:Running()
	end

	if status == "Success" then
		return self:Success()
	end

	return self:Fail(entity, reason)
end

function AdvanceExecutor:OnCancel(entity: number, services: any)
	services.MovementService:StopMovement(entity)
end

function AdvanceExecutor:OnComplete(entity: number, services: any)
	services.MovementService:StopMovement(entity)
end

return AdvanceExecutor
