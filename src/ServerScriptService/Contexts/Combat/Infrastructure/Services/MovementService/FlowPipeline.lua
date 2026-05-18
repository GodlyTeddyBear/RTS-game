--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CombatMovementConfig = require(ReplicatedStorage.Contexts.Combat.Config.CombatMovementConfig)
local ParallelQuery = require(ReplicatedStorage.Utilities.ParallelQuery)
local MovementTypes = require(script.Parent.Types)

type TFlowPipelineState = MovementTypes.TFlowPipelineState
type TFlowPublishedFrameState = MovementTypes.TFlowPublishedFrameState
type TFlowPublishedSolve = MovementTypes.TFlowPublishedSolve
type TFlowSeparationSolveSnapshot = MovementTypes.TFlowSeparationSolveSnapshot
type TManagedJob = MovementTypes.TManagedJob

local ManagedJobPolicies = ParallelQuery.ManagedJobPolicies

local function _TransitionFlowPipeline(self: any, nextState: TFlowPipelineState)
	local transitionResult = self._flowPipelineStateMachine:Transition(nextState)
	assert(
		transitionResult.success,
		tostring(transitionResult.message or transitionResult.type or "Illegal flow pipeline transition")
	)
end

return function(MovementService: any)
	function MovementService:_ReleaseFlowLatestParallelSolve()
		self._flowLatestParallelSolve = nil
		self._flowPublishedSolve.TickId = 0
		table.clear(self._flowPublishedVelocityByEntity)
		table.clear(self._flowPublishedTouchedSettledNeighborByEntity)
		table.clear(self._flowPublishedGoalKeyByEntity)
		table.clear(self._flowPublishedGoalPositionByEntity)
		table.clear(self._flowPublishedGoalWorldSampleByEntity)
		table.clear(self._flowPublishedPositionByEntity)
		table.clear(self._flowPublishedWalkSpeedByEntity)
		table.clear(self._flowPublishedIsSettledByEntity)
	end

	function MovementService:_ReleaseFlowDispatchedSeparationSnapshot()
		self._flowDispatchedSeparationSnapshot = nil
		self._flowDispatchedGoalKeyByEntity = nil
		self._flowDispatchedFrameState = nil
	end

	function MovementService:_GetFlowPipelineState(): TFlowPipelineState
		return self._flowPipelineStateMachine:GetState()
	end

	function MovementService:_GetFlowVelocityParallelMinEntityCount(): number
		local config = CombatMovementConfig.FLOW_SOFT_SEPARATION
		local configured = if config ~= nil then config.ParallelMinVelocityEntityCount else nil
		if type(configured) == "number" and configured >= 0 then
			return math.floor(configured)
		end
		return 1
	end

	function MovementService:_GetFlowSeparationParallelActorCount(): number
		local config = CombatMovementConfig.FLOW_SOFT_SEPARATION
		local configured = if config ~= nil then config.ParallelActorCount else nil
		if type(configured) == "number" and configured > 0 then
			return math.floor(configured)
		end
		return 32
	end

	function MovementService:_GetFlowSeparationParallelBatchSize(): number
		local config = CombatMovementConfig.FLOW_SOFT_SEPARATION
		local configured = if config ~= nil then config.ParallelVelocityBatchSize else nil
		if type(configured) == "number" and configured > 0 then
			return math.floor(configured)
		end
		return 8
	end

	function MovementService:_GetFlowSeparationParallelTimeoutSeconds(): number
		local config = CombatMovementConfig.FLOW_SOFT_SEPARATION
		local configured = if config ~= nil then config.ParallelVelocityTimeoutSeconds else nil
		if type(configured) == "number" and configured > 0 then
			return configured
		end
		return 1
	end

	function MovementService:_GetFlowSeparationParallelMaxInFlightSeconds(): number
		local config = CombatMovementConfig.FLOW_SOFT_SEPARATION
		local configured = if config ~= nil then config.ParallelAsyncMaxInFlightSeconds else nil
		if type(configured) == "number" and configured > 0 then
			return configured
		end
		return 1
	end

	function MovementService:_IsFlowSeparationParallelEnabled(): boolean
		local config = CombatMovementConfig.FLOW_SOFT_SEPARATION
		return config ~= nil and config.Enabled == true and config.ParallelEnabled == true
	end

	function MovementService:_GetOrCreateFlowSeparationRunner(): any
		local runner = self._flowSeparationParallelRunner
		if runner ~= nil then
			return runner
		end

		runner = ParallelQuery.new({
			Name = "CombatFlowMovement",
			ActorCount = self:_GetFlowSeparationParallelActorCount(),
			Operations = {
				script.Parent.Parallel.FlowSeparationSolveOperation,
			},
		})
		self._flowSeparationParallelRunner = runner
		return runner
	end

	function MovementService:_CreateFlowSeparationManagedJob(): TManagedJob
		local runner = self:_GetOrCreateFlowSeparationRunner()
		return runner:CreateManagedJob({
			OperationName = "FlowSeparationSolve",
			BuildLocalMemory = function(snapshot: TFlowSeparationSolveSnapshot)
				return self:_CreateFlowSeparationSharedMemory(snapshot)
			end,
			BuildRunRequest = function(snapshot: TFlowSeparationSolveSnapshot)
				local runRequest = self._flowRunRequest
				runRequest.WorkCount = #snapshot.EntityIds
				runRequest.BatchSize = self:_GetFlowSeparationParallelBatchSize()
				runRequest.TimeoutSeconds = self:_GetFlowSeparationParallelTimeoutSeconds()
				return runRequest
			end,
			GetSessionToken = function(_snapshot: TFlowSeparationSolveSnapshot)
				return self._flowCurrentSessionUserId
			end,
			MaxInFlightSeconds = self:_GetFlowSeparationParallelMaxInFlightSeconds(),
			Policy = ManagedJobPolicies.StrictFreshOnly,
		})
	end

	function MovementService:_GetOrCreateFlowSeparationManagedJob(): TManagedJob
		local job = self._flowSeparationManagedJob
		if job == nil then
			job = self:_CreateFlowSeparationManagedJob()
			self._flowSeparationManagedJob = job
		end
		return job
	end

	function MovementService:_DestroyFlowSeparationRunner()
		local runner = self._flowSeparationParallelRunner
		if runner ~= nil then
			runner:Destroy()
		end
		self._flowSeparationParallelRunner = nil
		self._flowSeparationManagedJob = nil
		self:_ReleaseFlowLatestParallelSolve()
		self:_ReleaseFlowDispatchedSeparationSnapshot()
		self:_DestroyFlowFrameState()
	end

	function MovementService:_ConsumeCompletedFlowSeparationSolve(): boolean
		local job = self._flowSeparationManagedJob
		if job == nil then
			return false
		end

		local status = job:GetStatus()
		if status.HasCompletedResult ~= true then
			return false
		end

		local managedResult = job:PollCompleted(self._flowCurrentSessionUserId)
		if managedResult == nil or managedResult.Err ~= nil or managedResult.Rows == nil then
			return false
		end

		local snapshot = managedResult.Payload :: TFlowSeparationSolveSnapshot
		local goalKeyByEntity = self._flowDispatchedGoalKeyByEntity
		local frameState = self._flowDispatchedFrameState :: TFlowPublishedFrameState?
		if snapshot ~= self._flowDispatchedSeparationSnapshot or goalKeyByEntity == nil or frameState == nil then
			return false
		end

		self:_ReleaseFlowLatestParallelSolve()

		local velocityByEntity = self:_ApplyFlowVelocityRows(
			snapshot,
			managedResult.Rows :: any,
			self._flowPublishedVelocityByEntity,
			self._flowPublishedTouchedSettledNeighborByEntity
		)
		if next(velocityByEntity) == nil then
			self:_ReleaseFlowDispatchedSeparationSnapshot()
			return false
		end

		local publishedGoalKeyByEntity = self._flowPublishedGoalKeyByEntity
		table.clear(publishedGoalKeyByEntity)
		for entityId, goalKey in goalKeyByEntity do
			publishedGoalKeyByEntity[entityId] = goalKey
		end

		local publishedGoalPositionByEntity = self._flowPublishedGoalPositionByEntity
		table.clear(publishedGoalPositionByEntity)
		for entityId, goalPosition in frameState.GoalPositionByEntity do
			publishedGoalPositionByEntity[entityId] = goalPosition
		end

		local publishedGoalWorldSampleByEntity = self._flowPublishedGoalWorldSampleByEntity
		table.clear(publishedGoalWorldSampleByEntity)
		for entityId, goalWorldSample in frameState.GoalWorldSampleByEntity do
			publishedGoalWorldSampleByEntity[entityId] = goalWorldSample
		end

		local publishedPositionByEntity = self._flowPublishedPositionByEntity
		table.clear(publishedPositionByEntity)
		for entityId, position in frameState.PositionByEntity do
			publishedPositionByEntity[entityId] = position
		end

		local publishedWalkSpeedByEntity = self._flowPublishedWalkSpeedByEntity
		table.clear(publishedWalkSpeedByEntity)
		for entityId, walkSpeed in frameState.WalkSpeedByEntity do
			publishedWalkSpeedByEntity[entityId] = walkSpeed
		end

		local publishedIsSettledByEntity = self._flowPublishedIsSettledByEntity
		table.clear(publishedIsSettledByEntity)
		for entityId, isSettled in frameState.IsSettledByEntity do
			if isSettled then
				publishedIsSettledByEntity[entityId] = true
			end
		end

		local publishedSolve = self._flowPublishedSolve :: TFlowPublishedSolve
		publishedSolve.TickId = snapshot.TickId
		self._flowLatestParallelSolve = publishedSolve
		self:_ReleaseFlowDispatchedSeparationSnapshot()
		return true
	end

	function MovementService:_TryDispatchFlowSeparationSolve(snapshot: TFlowSeparationSolveSnapshot): boolean
		if not self:_IsFlowSeparationParallelEnabled() then
			return false
		end
		if #snapshot.EntityIds < self:_GetFlowVelocityParallelMinEntityCount() then
			return false
		end

		local job = self:_GetOrCreateFlowSeparationManagedJob()
		local status = job:GetStatus()
		if status.InFlight then
			return false
		end

		local didDispatch = false
		pcall(function()
			job:Dispatch(snapshot)
			didDispatch = true
		end)
		return didDispatch
	end

	function MovementService:_PublishCompletedFlowSolve()
		if not self:_ConsumeCompletedFlowSeparationSolve() then
			self:_ReleaseFlowDispatchedSeparationSnapshot()
			_TransitionFlowPipeline(self, "Idle")
			return
		end

		_TransitionFlowPipeline(self, "Idle")
	end

	function MovementService:_AdvanceFlowPipeline(services: any?)
		local tickId = self:_ResolveFlowTickId(services)
		if self._flowPipelineTickId == tickId then
			return
		end

		self._flowPipelineTickId = tickId
		self._flowFrameSerial = tickId
		self._flowCurrentSessionUserId = self:_ResolveActiveSessionUserId()

		local state = self:_GetFlowPipelineState()
		if state == "Idle" then
			local snapshot, goalKeyByEntity, frameState =
				self:_BuildFlowDispatchSnapshot(tickId, self:_ResolveFlowDeltaTime(services))
			if snapshot == nil or goalKeyByEntity == nil or frameState == nil then
				return
			end

			self:_ReleaseFlowDispatchedSeparationSnapshot()
			self._flowDispatchedSeparationSnapshot = snapshot
			self._flowDispatchedGoalKeyByEntity = goalKeyByEntity
			self._flowDispatchedFrameState = frameState

			_TransitionFlowPipeline(self, "Dispatching")
			state = "Dispatching"
		end

		if state == "Dispatching" then
			local snapshot = self._flowDispatchedSeparationSnapshot
			if snapshot == nil or not self:_TryDispatchFlowSeparationSolve(snapshot) then
				self:_ReleaseFlowDispatchedSeparationSnapshot()
				_TransitionFlowPipeline(self, "Idle")
				return
			end

			_TransitionFlowPipeline(self, "Waiting")
			return
		end

		if state == "Waiting" then
			local job = self._flowSeparationManagedJob
			if job == nil then
				self:_ReleaseFlowDispatchedSeparationSnapshot()
				_TransitionFlowPipeline(self, "Idle")
				return
			end

			local status = job:GetStatus()
			if status.HasCompletedResult ~= true then
				return
			end

			_TransitionFlowPipeline(self, "Publishing")
			self:_PublishCompletedFlowSolve()
		end
	end
end
