--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local CombatMovementConfig = require(ReplicatedStorage.Contexts.Combat.Config.CombatMovementConfig)
local ParallelRunner = require(ServerStorage.Utilities.ParallelRunner)

local MovementFlowDispatchService = {}
MovementFlowDispatchService.__index = MovementFlowDispatchService

function MovementFlowDispatchService.new()
	local self = setmetatable({}, MovementFlowDispatchService)
	self._runner = nil
	self._job = nil
	return self
end

function MovementFlowDispatchService:Prime()
	if not self:_IsEnabled() or self._runner ~= nil then
		return
	end
	local runner = ParallelRunner.new({
		Name = "CombatFlowMovement",
		ActorCount = self:_GetNumber("ParallelActorCount", 32),
		DefaultBatchSize = self:_GetNumber("ParallelVelocityBatchSize", 8),
	})
	local result = runner:RegisterJob({
		Job = require(script.Parent.Parallel.FlowSeparationSolveOperation),
		WorkerModule = script.Parent.Parallel.FlowSeparationSolveWorker,
		ManagerModule = script.Parent.Parallel.FlowSeparationSolveManager,
	})
	if not result.success then
		runner:Destroy()
		return
	end
	self._runner = runner
	self._job = runner:CreateManagedJob({
		JobName = "FlowSeparationSolve",
		BuildSharedMemory = function(payload: any)
			return payload.SharedMemory
		end,
		BuildManagerPayload = function(payload: any)
			return payload.ManagerPayload
		end,
		BuildRunRequest = function(payload: any)
			return payload.RunRequest
		end,
		MaxInFlightSeconds = self:_GetNumber("ParallelAsyncMaxInFlightSeconds", 2),
		Policy = ParallelRunner.ManagedJobPolicies.StrictFreshOnly,
	})
end

function MovementFlowDispatchService:Dispatch(payload: any): boolean
	self:Prime()
	if self._runner == nil or self._job == nil then
		return false
	end
	return self._job:Dispatch(payload) == "Dispatched"
end

function MovementFlowDispatchService:Poll(): { [number]: Vector2 }?
	local job = self._job
	if job == nil then
		return nil
	end
	local result = job:PollCompleted(nil)
	if result == nil or result.Err ~= nil or type(result.Rows) ~= "table" then
		return nil
	end
	local payload = result.Payload
	local actorIds = if type(payload) == "table" then payload.ActorIds else nil
	if type(actorIds) ~= "table" then
		return nil
	end
	local velocityByEntity = {}
	for _, row in ipairs(result.Rows) do
		local entity = actorIds[row.EntityIndex]
		if type(entity) == "number" and type(row.VelocityX) == "number" and type(row.VelocityY) == "number" then
			velocityByEntity[entity] = Vector2.new(row.VelocityX, row.VelocityY)
		end
	end
	return velocityByEntity
end

function MovementFlowDispatchService:Reset()
	if self._job ~= nil then
		self._job:Reset()
	end
end

function MovementFlowDispatchService:Destroy()
	if self._job ~= nil then
		self._job:Destroy()
		self._job = nil
	end
	if self._runner ~= nil then
		self._runner:Destroy()
		self._runner = nil
	end
end

function MovementFlowDispatchService:_IsEnabled(): boolean
	local config = CombatMovementConfig.FLOW_SOFT_SEPARATION
	return config ~= nil and config.Enabled == true and config.ParallelEnabled == true
end

function MovementFlowDispatchService:_GetNumber(key: string, fallback: number): number
	local config = CombatMovementConfig.FLOW_SOFT_SEPARATION
	local value = if config ~= nil then config[key] else nil
	return if type(value) == "number" and value > 0 then math.floor(value) else fallback
end

return MovementFlowDispatchService
