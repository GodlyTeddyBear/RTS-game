--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Promise = require(ReplicatedStorage.Packages.Promise)
local PathfindingHelper = require(ReplicatedStorage.Utilities.PathfindingHelper)
local CombatMovementConfig = require(ReplicatedStorage.Contexts.Combat.Config.CombatMovementConfig)

local BaseExecutor = require(script.Parent.Base.BaseExecutor)

--[=[
	@class LaneAdvanceExecutor
	Drives enemy movement along the cached lane waypoints.
	@server
]=]
local LaneAdvanceExecutor = {}
LaneAdvanceExecutor.__index = LaneAdvanceExecutor
setmetatable(LaneAdvanceExecutor, { __index = BaseExecutor })

-- Creates a new lane-advance executor with per-entity path tracking.
function LaneAdvanceExecutor.new()
	local self = BaseExecutor.new({
		ActionId = "LaneAdvance",
		IsCommitted = false,
	})
	setmetatable(self, LaneAdvanceExecutor)
	self._promises = {}
	return self
end

-- Resolves the agent params from the enemy role so pathfinding matches the unit profile.
function LaneAdvanceExecutor:_GetAgentParams(entity: number, services: any): { [string]: any }
	local role = services.EnemyEntityFactory:GetRole(entity)
	if role then
		local config = CombatMovementConfig.AGENT_PARAMS_BY_ROLE[role.role]
		if config then
			return config
		end
	end
	return CombatMovementConfig.DEFAULT_AGENT_PARAMS
end

-- Starts the next path segment toward the current waypoint.
function LaneAdvanceExecutor:_StartPath(entity: number, services: any): boolean
	local pathState = services.EnemyEntityFactory:GetPathState(entity)
	if not pathState or not pathState.waypoints then
		return false
	end

	if pathState.waypointIndex > #pathState.waypoints then
		return false
	end

	local targetPosition = pathState.waypoints[pathState.waypointIndex]
	if not targetPosition then
		return false
	end

	local path = PathfindingHelper.CreatePath(entity, {
		EnemyEntityFactory = services.EnemyEntityFactory,
	}, self:_GetAgentParams(entity, services))
	if not path then
		return false
	end

	services.EnemyEntityFactory:SetPathMoving(entity, true)
	self._promises[entity] = PathfindingHelper.RunPath(path, targetPosition)
	return true
end

-- Begins lane advancement for one entity and returns whether the executor could start.
function LaneAdvanceExecutor:Start(entity: number, _data: any?, services: any): (boolean, string?)
	if self._promises[entity] then
		self:Cancel(entity, services)
	end

	local pathState = services.EnemyEntityFactory:GetPathState(entity)
	if not pathState or not pathState.waypoints or #pathState.waypoints == 0 then
		return false, "NoWaypoints"
	end

	if pathState.waypointIndex > #pathState.waypoints then
		return false, "AlreadyAtGoal"
	end

	if not self:_StartPath(entity, services) then
		return false, "PathStartFailed"
	end

	return true, nil
end

-- Advances the current path promise and returns the execution state for this tick.
function LaneAdvanceExecutor:Tick(entity: number, _dt: number, services: any): string
	local promise = self._promises[entity]
	if not promise then
		if self:_StartPath(entity, services) then
			return "Running"
		end
		return "Fail"
	end

	local status = promise:getStatus()
	if status == Promise.Status.Started then
		return "Running"
	end

	self._promises[entity] = nil
	services.EnemyEntityFactory:SetPathMoving(entity, false)

	if status == Promise.Status.Resolved then
		local pathState = services.EnemyEntityFactory:GetPathState(entity)
		if not pathState then
			return "Fail"
		end

		local nextWaypointIndex = pathState.waypointIndex + 1
		services.EnemyEntityFactory:SetWaypointIndex(entity, nextWaypointIndex)

		local updatedPathState = services.EnemyEntityFactory:GetPathState(entity)
		if not updatedPathState or nextWaypointIndex > #updatedPathState.waypoints then
			return "Success"
		end

		if self:_StartPath(entity, services) then
			return "Running"
		end
		return "Fail"
	end

	return "Fail"
end

-- Cancels the active path promise and clears movement state for the entity.
function LaneAdvanceExecutor:Cancel(entity: number, services: any)
	local promise = self._promises[entity]
	if promise then
		promise:cancel()
		self._promises[entity] = nil
	end
	services.EnemyEntityFactory:SetPathMoving(entity, false)
end

-- Completes by delegating to the same cleanup path as cancellation.
function LaneAdvanceExecutor:Complete(entity: number, services: any)
	self:Cancel(entity, services)
end

return LaneAdvanceExecutor
