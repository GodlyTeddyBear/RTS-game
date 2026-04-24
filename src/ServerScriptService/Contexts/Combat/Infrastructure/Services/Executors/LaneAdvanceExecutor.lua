--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Promise = require(ReplicatedStorage.Packages.Promise)
local PathfindingHelper = require(ReplicatedStorage.Utilities.PathfindingHelper)
local BaseExecutor = require(ReplicatedStorage.Utilities.BaseExecutor)
local CombatMovementConfig = require(ReplicatedStorage.Contexts.Combat.Config.CombatMovementConfig)

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
		AutoCleanupOnComplete = true,
	})
	setmetatable(self, LaneAdvanceExecutor)
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
	self:TrackAsyncResource(entity, "PathPromise", PathfindingHelper.RunPath(path, targetPosition), "cancel")
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
function LaneAdvanceExecutor:CanStart(entity: number, _data: any?, services: any): (boolean, string?)
	if self:GetAsyncResource(entity, "PathPromise") ~= nil then
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

function LaneAdvanceExecutor:CanContinue(entity: number, services: any): (boolean, string?)
	local pathState = services.EnemyEntityFactory:GetPathState(entity)
	if pathState == nil then
		return false, "MissingPathState"
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
function LaneAdvanceExecutor:OnTick(entity: number, _dt: number, services: any): string
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
		local pathState = services.EnemyEntityFactory:GetPathState(entity)
		if not pathState then
			return self:Fail(entity, "MissingPathState")
		end

		local nextWaypointIndex = pathState.waypointIndex + 1
		services.EnemyEntityFactory:SetWaypointIndex(entity, nextWaypointIndex)

		local updatedPathState = services.EnemyEntityFactory:GetPathState(entity)
		if not updatedPathState or nextWaypointIndex > #updatedPathState.waypoints then
			return self:Success()
		end

		if self:_StartPath(entity, services) then
			return self:Running()
		end
		return self:Fail(entity, "PathStartFailed")
	end

	return self:Fail(entity, "PathPromiseRejected")
end

--[=[
	@within LaneAdvanceExecutor
	Cancels the active path promise and clears movement state for the entity.
	@param entity number -- Enemy entity id being processed.
	@param services any -- Shared executor services for the current tick.
]=]
function LaneAdvanceExecutor:OnCancel(entity: number, services: any)
	services.EnemyEntityFactory:SetPathMoving(entity, false)
end

--[=[
	@within LaneAdvanceExecutor
	Completes by delegating to the same cleanup path as cancellation.
	@param entity number -- Enemy entity id being processed.
	@param services any -- Shared executor services for the current tick.
]=]
function LaneAdvanceExecutor:OnComplete(entity: number, services: any)
	services.EnemyEntityFactory:SetPathMoving(entity, false)
end

return LaneAdvanceExecutor
