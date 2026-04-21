--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Promise = require(ReplicatedStorage.Packages.Promise)
local PathfindingHelper = require(ReplicatedStorage.Utilities.PathfindingHelper)
local EnemyMovementConfig = require(ReplicatedStorage.Contexts.Enemy.Config.EnemyMovementConfig)

--[=[
	@class EnemyMovementService
	Drives lane pathing for active enemy entities.
	@server
]=]
local EnemyMovementService = {}
EnemyMovementService.__index = EnemyMovementService

function EnemyMovementService.new()
	local self = setmetatable({}, EnemyMovementService)
	self._promises = {} :: { [any]: any }
	self._goalReachedHandler = nil :: ((any) -> ())?
	return self
end

function EnemyMovementService:Init(registry: any, _name: string)
	self.EnemyEntityFactory = registry:Get("EnemyEntityFactory")
end

function EnemyMovementService:SetGoalReachedHandler(handler: ((any) -> ())?)
	self._goalReachedHandler = handler
end

function EnemyMovementService:_GetAgentParams(entity: any): { [string]: any }
	local role = self.EnemyEntityFactory:GetRole(entity)
	if role then
		local config = EnemyMovementConfig.AGENT_PARAMS_BY_ROLE[role.role]
		if config then
			return config
		end
	end

	return {
		AgentRadius = 2,
		AgentHeight = 5,
		AgentCanJump = true,
	}
end

function EnemyMovementService:_StartPath(entity: any, targetPosition: Vector3): boolean
	local path = PathfindingHelper.CreatePath(entity, {
		EnemyEntityFactory = self.EnemyEntityFactory,
	}, self:_GetAgentParams(entity))

	if not path then
		return false
	end

	self.EnemyEntityFactory:SetPathMoving(entity, true)
	self._promises[entity] = PathfindingHelper.RunPath(path, targetPosition)
	return true
end

function EnemyMovementService:_HandleGoalReached(entity: any)
	self._promises[entity] = nil
	self.EnemyEntityFactory:SetPathMoving(entity, false)

	local handler = self._goalReachedHandler
	if handler then
		handler(entity)
	end
end

function EnemyMovementService:_TickEntity(entity: any)
	local pathState = self.EnemyEntityFactory:GetPathState(entity)
	if not pathState or not pathState.waypoints or #pathState.waypoints == 0 then
		return
	end

	local promise = self._promises[entity]
	if promise then
		local status = promise:getStatus()
		if status == Promise.Status.Started then
			return
		end

		self._promises[entity] = nil
		self.EnemyEntityFactory:SetPathMoving(entity, false)

		if status == Promise.Status.Resolved then
			self.EnemyEntityFactory:SetWaypointIndex(entity, pathState.waypointIndex + 1)
			pathState = self.EnemyEntityFactory:GetPathState(entity)
			if not pathState or pathState.waypointIndex > #pathState.waypoints then
				self:_HandleGoalReached(entity)
				return
			end
		else
			return
		end
	end

	pathState = self.EnemyEntityFactory:GetPathState(entity)
	if not pathState or not pathState.waypoints then
		return
	end

	if pathState.waypointIndex > #pathState.waypoints then
		self:_HandleGoalReached(entity)
		return
	end

	local targetPosition = pathState.waypoints[pathState.waypointIndex]
	if targetPosition then
		self:_StartPath(entity, targetPosition)
	end
end

function EnemyMovementService:Tick()
	for _, entity in ipairs(self.EnemyEntityFactory:QueryAliveEntities()) do
		self:_TickEntity(entity)
	end
end

function EnemyMovementService:Cancel(entity: any)
	local promise = self._promises[entity]
	if promise then
		promise:cancel()
		self._promises[entity] = nil
	end

	self.EnemyEntityFactory:SetPathMoving(entity, false)
end

function EnemyMovementService:CancelAll()
	for entity, promise in pairs(self._promises) do
		if promise then
			promise:cancel()
		end
		self._promises[entity] = nil
	end
end

return EnemyMovementService
