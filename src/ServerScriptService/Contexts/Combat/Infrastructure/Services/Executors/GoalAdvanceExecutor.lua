--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Promise = require(ReplicatedStorage.Packages.Promise)
local PathfindingHelper = require(ReplicatedStorage.Utilities.PathfindingHelper)
local BaseExecutor = require(ReplicatedStorage.Utilities.BaseExecutor)
local CombatMovementConfig = require(ReplicatedStorage.Contexts.Combat.Config.CombatMovementConfig)

--[=[
	@class GoalAdvanceExecutor
	Drives enemy movement directly toward the current map goal.
	@server
]=]
local GoalAdvanceExecutor = {}
GoalAdvanceExecutor.__index = GoalAdvanceExecutor
setmetatable(GoalAdvanceExecutor, { __index = BaseExecutor })

function GoalAdvanceExecutor.new()
	local self = BaseExecutor.new({
		ActionId = "GoalAdvance",
		IsCommitted = false,
		AutoCleanupOnComplete = true,
	})
	setmetatable(self, GoalAdvanceExecutor)
	return self
end

function GoalAdvanceExecutor:_GetAgentParams(entity: number, services: any): { [string]: any }
	local role = services.EnemyEntityFactory:GetRole(entity)
	if role then
		local config = CombatMovementConfig.AGENT_PARAMS_BY_ROLE[role.role]
		if config then
			return config
		end
	end
	return CombatMovementConfig.DEFAULT_AGENT_PARAMS
end

function GoalAdvanceExecutor:_StartPath(entity: number, services: any): boolean
	local pathState = services.EnemyEntityFactory:GetPathState(entity)
	if not pathState or pathState.goalPosition == nil then
		return false
	end

	local path = PathfindingHelper.CreatePath(entity, {
		EnemyEntityFactory = services.EnemyEntityFactory,
	}, self:_GetAgentParams(entity, services))
	if not path then
		return false
	end

	services.EnemyEntityFactory:SetPathMoving(entity, true)
	self:TrackAsyncResource(entity, "PathPromise", PathfindingHelper.RunPath(path, pathState.goalPosition, entity), "cancel")
	return true
end

function GoalAdvanceExecutor:CanStart(entity: number, _data: any?, services: any): (boolean, string?)
	if self:GetAsyncResource(entity, "PathPromise") ~= nil then
		self:Cancel(entity, services)
	end

	local pathState = services.EnemyEntityFactory:GetPathState(entity)
	if not pathState or pathState.goalPosition == nil then
		return false, "MissingGoalPosition"
	end

	if not self:_StartPath(entity, services) then
		return false, "PathStartFailed"
	end

	return true, nil
end

function GoalAdvanceExecutor:CanContinue(entity: number, services: any): (boolean, string?)
	local pathState = services.EnemyEntityFactory:GetPathState(entity)
	if pathState == nil then
		return false, "MissingPathState"
	end

	if pathState.goalPosition == nil then
		return false, "MissingGoalPosition"
	end

	return true, nil
end

function GoalAdvanceExecutor:OnTick(entity: number, _dt: number, services: any): string
	local promise = self:GetAsyncResource(entity, "PathPromise")
	if not promise then
		if self:_StartPath(entity, services) then
			return self:Running()
		end
		return self:Fail(entity, "PathStartFailed")
	end

	local status = promise:getStatus()
	if status == Promise.Status.Started then
		return self:Running()
	end

	self:ReleaseAsyncResource(entity, "PathPromise", false)
	services.EnemyEntityFactory:SetPathMoving(entity, false)

	if status == Promise.Status.Resolved then
		return self:Success()
	end

	return self:Fail(entity, "PathPromiseRejected")
end

function GoalAdvanceExecutor:OnCancel(entity: number, services: any)
	services.EnemyEntityFactory:SetPathMoving(entity, false)
end

function GoalAdvanceExecutor:OnComplete(entity: number, services: any)
	services.EnemyEntityFactory:SetPathMoving(entity, false)
end

return GoalAdvanceExecutor
