--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CombatMovementConfig = require(ReplicatedStorage.Contexts.Combat.Config.CombatMovementConfig)
local DebugConfig = require(ReplicatedStorage.Config.DebugConfig)
local DebugPlus = require(ReplicatedStorage.Utilities.DebugPlus)
local ParallelQuery = require(ReplicatedStorage.Utilities.ParallelQuery)
local MovementTypes = require(script.Parent.Types)

type TFlowPipelineState = MovementTypes.TFlowPipelineState
type TFlowPublishedFrameState = MovementTypes.TFlowPublishedFrameState
type TFlowPublishedSolve = MovementTypes.TFlowPublishedSolve
type TFlowSeparationSolveSnapshot = MovementTypes.TFlowSeparationSolveSnapshot
type TManagedJob = MovementTypes.TManagedJob

local ManagedJobPolicies = ParallelQuery.ManagedJobPolicies
local MOVEMENT_PROFILING_ENABLED = DebugConfig.COMBAT_MOVEMENT_PROFILING
local ADVANCE_PIPELINE_PROFILE_TAG = "Combat:MovementService:Flow:AdvancePipeline"
local PIPELINE_IDLE_BUILD_SNAPSHOT_PROFILE_TAG = "Combat:MovementService:Flow:AdvancePipeline:Idle:BuildSnapshot"
local PIPELINE_DISPATCHING_DISPATCH_PROFILE_TAG = "Combat:MovementService:Flow:AdvancePipeline:Dispatching:Dispatch"
local CONSUME_COMPLETED_SOLVE_PROFILE_TAG = "Combat:MovementService:Flow:ConsumeCompletedSolve"
local TRY_DISPATCH_PROFILE_TAG = "Combat:MovementService:Flow:TryDispatch"

-- Applies the next legal flow-pipeline state transition and asserts on invalid edges.
local function _TransitionFlowPipeline(self: any, nextState: TFlowPipelineState)
	local transitionResult = self._flowPipelineStateMachine:Transition(nextState)
	assert(
		transitionResult.success,
		tostring(transitionResult.message or transitionResult.type or "Illegal flow pipeline transition")
	)
end

return function(MovementService: any)
	-- Clears the published solve cache after the main thread finishes consuming it.
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

	-- Clears the dispatched flow snapshot and its per-entity goal caches.
	function MovementService:_ReleaseFlowDispatchedSeparationSnapshot()
		self._flowDispatchedSeparationSnapshot = nil
		self._flowDispatchedGoalKeyByEntity = nil
		self._flowDispatchedFrameState = nil
	end

	-- Returns the current flow pipeline state.
	function MovementService:_GetFlowPipelineState(): TFlowPipelineState
		return self._flowPipelineStateMachine:GetState()
	end

	-- Returns the minimum entity count required before parallel velocity solving is worthwhile.
	function MovementService:_GetFlowVelocityParallelMinEntityCount(): number
		local config = CombatMovementConfig.FLOW_SOFT_SEPARATION
		local configured = if config ~= nil then config.ParallelMinVelocityEntityCount else nil
		if type(configured) == "number" and configured >= 0 then
			return math.floor(configured)
		end
		return 1
	end

	-- Returns how many parallel actors the flow separation runner should spawn.
	function MovementService:_GetFlowSeparationParallelActorCount(): number
		local config = CombatMovementConfig.FLOW_SOFT_SEPARATION
		local configured = if config ~= nil then config.ParallelActorCount else nil
		if type(configured) == "number" and configured > 0 then
			return math.floor(configured)
		end
		return 32
	end

	-- Returns the batch size used to partition flow separation work across actors.
	function MovementService:_GetFlowSeparationParallelBatchSize(): number
		local config = CombatMovementConfig.FLOW_SOFT_SEPARATION
		local configured = if config ~= nil then config.ParallelVelocityBatchSize else nil
		if type(configured) == "number" and configured > 0 then
			return math.floor(configured)
		end
		return 8
	end

	-- Returns the timeout used while waiting for a separation result.
	function MovementService:_GetFlowSeparationParallelTimeoutSeconds(): number
		local config = CombatMovementConfig.FLOW_SOFT_SEPARATION
		local configured = if config ~= nil then config.ParallelVelocityTimeoutSeconds else nil
		if type(configured) == "number" and configured > 0 then
			return configured
		end
		return 1
	end

	-- Returns the maximum in-flight time allowed for the managed parallel job.
	function MovementService:_GetFlowSeparationParallelMaxInFlightSeconds(): number
		local config = CombatMovementConfig.FLOW_SOFT_SEPARATION
		local configured = if config ~= nil then config.ParallelAsyncMaxInFlightSeconds else nil
		if type(configured) == "number" and configured > 0 then
			return configured
		end
		return 1
	end

	-- Returns whether the parallel flow separation runner is enabled.
	function MovementService:_IsFlowSeparationParallelEnabled(): boolean
		local config = CombatMovementConfig.FLOW_SOFT_SEPARATION
		return config ~= nil and config.Enabled == true and config.ParallelEnabled == true
	end

	-- Lazily creates the parallel runner that evaluates flow separation jobs.
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

	-- Builds the managed parallel job wrapper used for flow separation dispatch.
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

	-- Lazily creates the managed job wrapper for the flow separation runner.
	function MovementService:_GetOrCreateFlowSeparationManagedJob(): TManagedJob
		local job = self._flowSeparationManagedJob
		if job == nil then
			job = self:_CreateFlowSeparationManagedJob()
			self._flowSeparationManagedJob = job
		end
		return job
	end

	-- Resets the flow-infrastructure runtime without destroying shared objects.
	function MovementService:_ResetFlowInfrastructureRuntime()
		local job = self._flowSeparationManagedJob
		if job ~= nil then
			job:Reset()
		end

		self:_ReleaseFlowLatestParallelSolve()
		self:_ReleaseFlowDispatchedSeparationSnapshot()
		local frameState = self._flowFrameState
		if frameState ~= nil then
			frameState:Reset()
		end
	end

	-- Destroys the parallel flow infrastructure and its cached frame-state objects.
	function MovementService:_DestroyFlowInfrastructure()
		local job = self._flowSeparationManagedJob
		if job ~= nil then
			job:Destroy()
		end
		self._flowSeparationManagedJob = nil

		local runner = self._flowSeparationParallelRunner
		if runner ~= nil then
			runner:Destroy()
		end
		self._flowSeparationParallelRunner = nil

		self:_ReleaseFlowLatestParallelSolve()
		self:_ReleaseFlowDispatchedSeparationSnapshot()
		self:_DestroyFlowFrameState()
	end

	-- Polls the managed job and publishes the completed flow solve when available.
	function MovementService:_ConsumeCompletedFlowSeparationSolve(): boolean
		local closeConsumeProfile = DebugPlus.begin(CONSUME_COMPLETED_SOLVE_PROFILE_TAG, MOVEMENT_PROFILING_ENABLED)
		local job = self._flowSeparationManagedJob
		if job == nil then
			closeConsumeProfile()
			return false
		end

		-- Reject jobs that have not actually produced a completed result yet.
		local status = job:GetStatus()
		if status.HasCompletedResult ~= true then
			closeConsumeProfile()
			return false
		end

		local managedResult = job:PollCompleted(self._flowCurrentSessionUserId)
		if managedResult == nil or managedResult.Err ~= nil or managedResult.Rows == nil then
			closeConsumeProfile()
			return false
		end

		-- Validate that the completed result matches the snapshot we dispatched earlier.
		local snapshot = managedResult.Payload :: TFlowSeparationSolveSnapshot
		local goalKeyByEntity = self._flowDispatchedGoalKeyByEntity
		local frameState = self._flowDispatchedFrameState :: TFlowPublishedFrameState?
		if snapshot ~= self._flowDispatchedSeparationSnapshot or goalKeyByEntity == nil or frameState == nil then
			closeConsumeProfile()
			return false
		end

		-- Publish the solve outputs into the reusable frame caches.
		self:_ReleaseFlowLatestParallelSolve()

		local velocityByEntity = self:_ApplyFlowVelocityRows(
			snapshot,
			managedResult.Rows :: any,
			self._flowPublishedVelocityByEntity,
			self._flowPublishedTouchedSettledNeighborByEntity
		)
		if next(velocityByEntity) == nil then
			self:_ReleaseFlowDispatchedSeparationSnapshot()
			closeConsumeProfile()
			return false
		end

		-- Copy the per-entity goal, position, and settle state into published tables.
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
		closeConsumeProfile()
		return true
	end

	-- Dispatches the flow separation solve when the runtime and workload are ready.
	function MovementService:_TryDispatchFlowSeparationSolve(snapshot: TFlowSeparationSolveSnapshot): boolean
		local closeTryDispatchProfile = DebugPlus.begin(TRY_DISPATCH_PROFILE_TAG, MOVEMENT_PROFILING_ENABLED)
		if not self:_IsFlowSeparationParallelEnabled() then
			closeTryDispatchProfile()
			return false
		end
		if #snapshot.EntityIds < self:_GetFlowVelocityParallelMinEntityCount() then
			closeTryDispatchProfile()
			return false
		end

		local job = self:_GetOrCreateFlowSeparationManagedJob()
		local status = job:GetStatus()
		if status.InFlight then
			closeTryDispatchProfile()
			return false
		end

		local didDispatch = false
		pcall(function()
			job:Dispatch(snapshot)
			didDispatch = true
		end)
		closeTryDispatchProfile()
		return didDispatch
	end

	-- Consumes the completed solve and returns the pipeline to idle.
	function MovementService:_PublishCompletedFlowSolve()
		if not self:_ConsumeCompletedFlowSeparationSolve() then
			self:_ReleaseFlowDispatchedSeparationSnapshot()
			_TransitionFlowPipeline(self, "Idle")
			return
		end

		_TransitionFlowPipeline(self, "Idle")
	end

	-- Advances the flow pipeline once per scheduler tick.
	function MovementService:_AdvanceFlowPipeline(services: any?)
		DebugPlus.profile(ADVANCE_PIPELINE_PROFILE_TAG, function()
			local tickId = self:_ResolveFlowTickId(services)
			if self._flowPipelineTickId == tickId then
				return
			end

			self._flowPipelineTickId = tickId
			self._flowFrameSerial = tickId
			self._flowCurrentSessionUserId = self:_ResolveActiveSessionUserId()

			local state = self:_GetFlowPipelineState()
			if state == "Idle" then
				-- Build a new dispatch snapshot before handing work to the parallel runner.
				local closeBuildSnapshotProfile =
					DebugPlus.begin(PIPELINE_IDLE_BUILD_SNAPSHOT_PROFILE_TAG, MOVEMENT_PROFILING_ENABLED)
				local snapshot, goalKeyByEntity, frameState =
					self:_BuildFlowDispatchSnapshot(tickId, self:_ResolveFlowDeltaTime(services))
				closeBuildSnapshotProfile()
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
				-- Submit the dispatch snapshot once the pipeline has a valid payload.
				local snapshot = self._flowDispatchedSeparationSnapshot
				local didDispatch = false
				if snapshot ~= nil then
					local closeDispatchProfile =
						DebugPlus.begin(PIPELINE_DISPATCHING_DISPATCH_PROFILE_TAG, MOVEMENT_PROFILING_ENABLED)
					didDispatch = self:_TryDispatchFlowSeparationSolve(snapshot)
					closeDispatchProfile()
				end
				if snapshot == nil or not didDispatch then
					self:_ReleaseFlowDispatchedSeparationSnapshot()
					_TransitionFlowPipeline(self, "Idle")
					return
				end

				_TransitionFlowPipeline(self, "Waiting")
				return
			end

			if state == "Waiting" then
				-- Wait for the parallel runner to finish before publishing the solve.
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
		end, MOVEMENT_PROFILING_ENABLED)
	end
end
