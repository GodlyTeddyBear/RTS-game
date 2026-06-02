--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local CombatMovementConfig = require(ReplicatedStorage.Contexts.Combat.Config.CombatMovementConfig)
local PathfindingHelper = require(ServerStorage.Utilities.PathfindingHelper)
local Promise = require(ReplicatedStorage.Packages.Promise)

local MovementPathRuntimeService = {}
MovementPathRuntimeService.__index = MovementPathRuntimeService

local GOAL_POSITION_EPSILON = 0.01

function MovementPathRuntimeService.new()
	local self = setmetatable({}, MovementPathRuntimeService)
	self._actorReadService = nil
	self._entityContext = nil
	self._runtimeByEntity = {}
	return self
end

function MovementPathRuntimeService:Configure(actorReadService: any, entityContext: any)
	self._actorReadService = actorReadService
	self._entityContext = entityContext
end

function MovementPathRuntimeService:StartOrRetarget(entityFactory: any, entity: number, goalPosition: Vector3): (boolean, string?)
	local runtime = self._runtimeByEntity[entity]
	if runtime ~= nil then
		if (runtime.GoalPosition - goalPosition).Magnitude <= GOAL_POSITION_EPSILON then
			return true, nil
		end
		self:Stop(entity)
	end

	local path = self:_CreatePath(entityFactory, entity)
	if path == nil then
		return false, "PathStartFailed"
	end

	self._runtimeByEntity[entity] = {
		Path = path,
		GoalPosition = goalPosition,
		Promise = PathfindingHelper.RunPath(path, goalPosition, entity, CombatMovementConfig.PATHFINDING),
	}
	return true, nil
end

function MovementPathRuntimeService:Poll(entity: number): ("Running" | "Done" | "Failed", string?)
	local runtime = self._runtimeByEntity[entity]
	if runtime == nil then
		return "Failed", "MissingPathRuntime"
	end

	local status = runtime.Promise:getStatus()
	if status == Promise.Status.Started then
		return "Running", nil
	end

	self._runtimeByEntity[entity] = nil
	if status == Promise.Status.Resolved then
		return "Done", nil
	end
	return "Failed", "PathPromiseRejected"
end

function MovementPathRuntimeService:Stop(entity: number)
	local runtime = self._runtimeByEntity[entity]
	if runtime == nil then
		return
	end
	self._runtimeByEntity[entity] = nil
	if runtime.Promise ~= nil and type(runtime.Promise.cancel) == "function" then
		runtime.Promise:cancel()
	end
	if runtime.Path ~= nil then
		pcall(function()
			runtime.Path:Destroy()
		end)
	end
end

function MovementPathRuntimeService:CleanupAll()
	local entities = {}
	for entity in self._runtimeByEntity do
		table.insert(entities, entity)
	end
	for _, entity in ipairs(entities) do
		self:Stop(entity)
	end
end

function MovementPathRuntimeService:_CreatePath(entityFactory: any, entity: number): any?
	local actorReadService = self._actorReadService
	local entityContext = self._entityContext
	if actorReadService == nil or entityContext == nil then
		return nil
	end

	return PathfindingHelper.CreatePath(entity, {
		EntityFactory = {
			GetModelRef = function(_factory: any, requestedEntity: number)
				if requestedEntity ~= entity then
					return nil
				end
				return actorReadService:GetModelRef(entityFactory, entityContext, entity)
			end,
		},
	}, CombatMovementConfig.DEFAULT_AGENT_PARAMS, CombatMovementConfig.PATHFINDING)
end

return MovementPathRuntimeService
