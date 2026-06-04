--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Result = require(ReplicatedStorage.Utilities.Result)
local EntityPhases = require(ReplicatedStorage.Contexts.Entity.Config.EntityPhases)

local EntityRuntimeSchedulerService = {}
EntityRuntimeSchedulerService.__index = EntityRuntimeSchedulerService

function EntityRuntimeSchedulerService.new(baseContext: any, entityContext: any)
	local self = setmetatable({}, EntityRuntimeSchedulerService)
	self._baseContext = baseContext
	self._entityContext = entityContext
	self._schedulerTickBound = false
	self._movementSchedulerTickBound = false
	self._runtimeTickActive = false
	self._movementRuntimeTickActive = false
	return self
end

function EntityRuntimeSchedulerService:Init(registry: any, _name: string)
	self._lifecycle = registry:Get("EntityLifecycleStateMachine")
	self._systemRegistry = registry:Get("EntitySystemRegistry")
	self._instanceBindingService = registry:Get("EntityInstanceBindingService")
	self._runtimeParticipation = registry:Get("EntityRuntimeParticipationService")
	self._runtimeSyncService = registry:Get("EntityRuntimeSyncService")
	self._replicationService = registry:Get("EntityReplicationService")
	self._entityFactory = registry:Get("EntityEntityFactory")
end

function EntityRuntimeSchedulerService:BindSchedulerTick()
	if self._schedulerTickBound then
		return
	end

	self._schedulerTickBound = true
	self._movementSchedulerTickBound = true
	self._baseContext:RegisterSchedulerSystem(EntityPhases.MovementSchedulerPhase, function()
		self:RunMovementScheduledTick()
	end)
	self._baseContext:RegisterSchedulerSystem(EntityPhases.SchedulerPhase, function()
		self:RunScheduledTick()
	end)
end

function EntityRuntimeSchedulerService:StopRuntimeTick()
	self._runtimeTickActive = false
	self._movementRuntimeTickActive = false
end

function EntityRuntimeSchedulerService:RunMovementScheduledTick()
	local ensureRuntimeResult = self._entityContext:_EnsureRuntimeStarted()
	if not ensureRuntimeResult.success then
		self._movementRuntimeTickActive = false
		self:_MentionTickFailure("Entity runtime startup finalization failed before movement tick", ensureRuntimeResult)
		return
	end

	if self._lifecycle:GetState() ~= "Running" then
		self._movementRuntimeTickActive = false
		return
	end

	self._movementRuntimeTickActive = true

	local runResult = self._systemRegistry:RunPhases(EntityPhases.MovementOrdered)
	self:_MentionTickFailure("Entity movement phases failed", runResult)
end

function EntityRuntimeSchedulerService:RunScheduledTick()
	local ensureRuntimeResult = self._entityContext:_EnsureRuntimeStarted()
	if not ensureRuntimeResult.success then
		self._runtimeTickActive = false
		self:_MentionTickFailure("Entity runtime startup finalization failed", ensureRuntimeResult)
		return
	end

	if self._lifecycle:GetState() ~= "Running" then
		self._runtimeTickActive = false
		return
	end

	self._runtimeTickActive = true

	local bindResult = self._instanceBindingService:FlushBindQueue(self._entityContext, function(entity: number, _instance: Instance)
		self:_OnRuntimeEntityBound(entity)
	end)
	self:_MentionTickFailure("Entity bind queue flush failed", bindResult)

	local runResult = self._systemRegistry:RunPhases(EntityPhases.RuntimeOrdered)
	self:_MentionTickFailure("Entity system tick failed", runResult)

	local reliableResult = self._replicationService:FlushReliableResult()
	self:_MentionTickFailure("Entity reliable replication flush failed", reliableResult)

	local unreliableResult = self._replicationService:FlushUnreliableResult()
	self:_MentionTickFailure("Entity unreliable replication flush failed", unreliableResult)
end

function EntityRuntimeSchedulerService:GetStatus(): any
	return table.freeze({
		SchedulerBound = self._schedulerTickBound,
		MovementSchedulerBound = self._movementSchedulerTickBound,
		RuntimeTickActive = self._runtimeTickActive,
		MovementRuntimeTickActive = self._movementRuntimeTickActive,
	})
end

function EntityRuntimeSchedulerService:_OnRuntimeEntityBound(entity: number): Result.Result<boolean>
	local featureName = self._runtimeParticipation:GetFeatureName(entity)
	if featureName == nil then
		return Result.Ok(false)
	end

	if self._runtimeParticipation:IsFeatureEnabled("Replication", featureName) then
		return self._replicationService:RegisterRuntimeEntity(self._entityContext, entity)
	end

	return Result.Ok(true)
end

function EntityRuntimeSchedulerService:_MentionTickFailure(message: string, result: Result.Result<any>)
	if result.success then
		return
	end

	Result.MentionError("EntityRuntimeSchedulerService:RunScheduledTick", message, {
		CauseType = result.type,
		CauseMessage = result.message,
		Details = result.data,
	}, result.type)
end

return EntityRuntimeSchedulerService
