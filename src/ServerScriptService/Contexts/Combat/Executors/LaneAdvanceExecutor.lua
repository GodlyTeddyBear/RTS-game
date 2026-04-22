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

--[=[
	@within LaneAdvanceExecutor
	Creates a new lane-advance executor with per-entity path tracking.
	@return LaneAdvanceExecutor -- Executor instance that manages lane movement.
]=]
function LaneAdvanceExecutor.new()
	local self = BaseExecutor.new({
		ActionId = "LaneAdvance",
		IsCommitted = false,
	})
	setmetatable(self, LaneAdvanceExecutor)
	self._promises = {}
	return self
end

--[=[
	@within LaneAdvanceExecutor
	Resolves the agent params from the enemy role so pathfinding matches the unit profile.
	@param entity number -- Enemy entity id being processed.
	@param services any -- Shared executor services for the current tick.
	@return { [string]: any } -- SimplePath agent parameters for the entity.
]=]
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

--[=[
	@within LaneAdvanceExecutor
	Starts the next path segment toward the current waypoint.
	@param entity number -- Enemy entity id being processed.
	@param services any -- Shared executor services for the current tick.
	@return boolean -- Whether a path segment started successfully.
]=]
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

--[=[
	@within LaneAdvanceExecutor
	Begins lane advancement for one entity and returns whether the executor could start.
	@param entity number -- Enemy entity id being processed.
	@param _data any? -- Unused action payload.
	@param services any -- Shared executor services for the current tick.
	@return boolean -- Whether the action started successfully.
	@return string? -- Optional failure reason when the action cannot start.
]=]
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

--[=[
	@within LaneAdvanceExecutor
	Advances the current path promise and returns the execution state for this tick.
	@param entity number -- Enemy entity id being processed.
	@param _dt number -- Frame delta time for the current tick.
	@param services any -- Shared executor services for the current tick.
	@return string -- Current action status for the executor pipeline.
]=]
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

--[=[
	@within LaneAdvanceExecutor
	Cancels the active path promise and clears movement state for the entity.
	@param entity number -- Enemy entity id being processed.
	@param services any -- Shared executor services for the current tick.
]=]
function LaneAdvanceExecutor:Cancel(entity: number, services: any)
	local promise = self._promises[entity]
	if promise then
		promise:cancel()
		self._promises[entity] = nil
	end
	services.EnemyEntityFactory:SetPathMoving(entity, false)
end

--[=[
	@within LaneAdvanceExecutor
	Completes by delegating to the same cleanup path as cancellation.
	@param entity number -- Enemy entity id being processed.
	@param services any -- Shared executor services for the current tick.
]=]
function LaneAdvanceExecutor:Complete(entity: number, services: any)
	self:Cancel(entity, services)
end

return LaneAdvanceExecutor
