--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local CombatMovementConfig = require(ReplicatedStorage.Contexts.Combat.Config.CombatMovementConfig)
local DebugConfig = require(ReplicatedStorage.Config.DebugConfig)
local DebugPlus = require(ReplicatedStorage.Utilities.DebugPlus)
local ParallelRunner = require(ServerStorage.Utilities.ParallelRunner)
local Result = require(ReplicatedStorage.Utilities.Result)
local MovementTypes = require(script.Parent.Types)
local Errors = require(script.Parent.Parent.Parent.Parent.Errors)

type TFlowSchedulerServices = MovementTypes.TFlowSchedulerServices
type TFlowPipelineState = MovementTypes.TFlowPipelineState
type TFlowPublishedFrameState = MovementTypes.TFlowPublishedFrameState
type TFlowPublishedSolve = MovementTypes.TFlowPublishedSolve
type TFlowSeparationDispatchPayload = MovementTypes.TFlowSeparationDispatchPayload
type TFlowSeparationManagerPayload = MovementTypes.TFlowSeparationManagerPayload
type TFlowSeparationSolveRow = MovementTypes.TFlowSeparationSolveRow
type TManagedJob = MovementTypes.TManagedJob
type TMovementService = MovementTypes.TMovementService
type TParallelRunnerLike = MovementTypes.TParallelRunnerLike

local ManagedJobPolicies = ParallelRunner.ManagedJobPolicies
local MOVEMENT_PROFILING_ENABLED = DebugConfig.COMBAT_MOVEMENT_PROFILING
local ADVANCE_PIPELINE_PROFILE_TAG = "Combat:MovementService:Flow:AdvancePipeline"
local PIPELINE_BUILDING_SNAPSHOT_PROFILE_TAG = "Combat:MovementService:Flow:AdvancePipeline:BuildingSnapshot"
local PIPELINE_PREPARING_SHARED_PACKET_PROFILE_TAG = "Combat:MovementService:Flow:AdvancePipeline:PreparingSharedPacket"
local PIPELINE_PREPARING_RUN_REQUEST_PROFILE_TAG = "Combat:MovementService:Flow:AdvancePipeline:PreparingRunRequest"
local PIPELINE_DISPATCHING_DISPATCH_PROFILE_TAG = "Combat:MovementService:Flow:AdvancePipeline:Dispatching:Dispatch"
local CONSUME_COMPLETED_SOLVE_PROFILE_TAG = "Combat:MovementService:Flow:ConsumeCompletedSolve"
local TRY_DISPATCH_PROFILE_TAG = "Combat:MovementService:Flow:TryDispatch"
local TRY_DISPATCH_MANAGED_DISPATCH_PROFILE_TAG = "Combat:MovementService:Flow:TryDispatch:ManagedDispatch"
local Ok = Result.Ok
local Err = Result.Err
local fromPcall = Result.fromPcall

-- Applies the next legal flow-pipeline state transition and asserts on invalid edges.
local function _TransitionFlowPipeline(self: TMovementService, nextState: TFlowPipelineState)
	local transitionResult = self._flowPipelineStateMachine:Transition(nextState)
	if not transitionResult.success then
		Result.MentionError("Combat:MovementService", "Illegal flow pipeline transition", {
			FromState = self._flowPipelineStateMachine:GetState(),
			ToState = nextState,
			CauseType = transitionResult.type,
			CauseMessage = transitionResult.message,
		}, "IllegalFlowPipelineTransition")
	end
end

local function _CountEntries<K, V>(map: { [K]: V }): number
	local count = 0
	for _ in map do
		count += 1
	end
	return count
end

return function(MovementService: TMovementService)
	-- Clears the staged payload that is handed to the managed job.
	function MovementService:_ReleaseFlowDispatchPayload()
		self._flowPreparedWorkerPayload = nil
		self._flowDispatchPayload = nil
	end

	-- Clears the published solve cache after the main thread finishes consuming it.
	function MovementService:_ReleaseFlowLatestParallelSolve()
		self._flowLatestParallelSolve = nil
		self._flowPublishedSolve.TickId = 0
		table.clear(self._flowPublishedVelocityByActorKey)
		table.clear(self._flowPublishedTouchedSettledNeighborByActorKey)
		table.clear(self._flowPublishedGoalKeyByActorKey)
		table.clear(self._flowPublishedGoalPositionByActorKey)
		table.clear(self._flowPublishedGoalWorldSampleByActorKey)
		table.clear(self._flowPublishedPositionByActorKey)
		table.clear(self._flowPublishedWalkSpeedByActorKey)
		table.clear(self._flowPublishedIsSettledByActorKey)
	end

	-- Clears the dispatched flow snapshot, staged payload, and per-entity goal caches.
	function MovementService:_ReleaseFlowDispatchedSeparationSnapshot()
		self:_ReleaseFlowDispatchPayload()
		self._flowDispatchedSeparationSnapshot = nil
		self._flowDispatchedActorKeys = nil
		self._flowDispatchedGoalKeyByActorKey = nil
		self._flowDispatchedFrameState = nil
	end

	-- Returns the current flow pipeline state.
	function MovementService:_GetFlowPipelineState(): TFlowPipelineState
		return self._flowPipelineStateMachine:GetState()
	end

	-- Returns whether the current combat frame still has enough budget to run another pipeline stage.
	function MovementService:_CanAdvanceFlowPipelineStage(
		services: TFlowSchedulerServices?,
		_stageName: TFlowPipelineState
	): boolean
		if type(services) ~= "table" then
			return true
		end

		local tickStartedAt = services.TickStartedAt
		local tickBudgetSeconds = services.TickBudgetSeconds
		if type(tickStartedAt) ~= "number" or type(tickBudgetSeconds) ~= "number" or tickBudgetSeconds <= 0 then
			return true
		end

		local reserveSeconds = DebugConfig.COMBAT_MOVEMENT_PIPELINE_STAGE_RESERVE_SECONDS
		if type(reserveSeconds) ~= "number" or reserveSeconds < 0 then
			reserveSeconds = 0
		end

		local elapsedSeconds = os.clock() - tickStartedAt
		local remainingSeconds = tickBudgetSeconds - elapsedSeconds
		return remainingSeconds > reserveSeconds
	end

	-- Returns the minimum entity count required before parallel velocity solving is worthwhile.
	function MovementService:_GetFlowVelocityParallelMinEntityCount(): number
		local config = CombatMovementConfig.FLOW_SOFT_SEPARATION
		local configured = config and config.ParallelMinVelocityEntityCount or nil
		if type(configured) == "number" and configured >= 0 then
			return math.floor(configured)
		end
		return 1
	end

	-- Returns how many parallel actors the flow separation runner should spawn.
	function MovementService:_GetFlowSeparationParallelActorCount(): number
		local config = CombatMovementConfig.FLOW_SOFT_SEPARATION
		local configured = config and config.ParallelActorCount or nil
		if type(configured) == "number" and configured > 0 then
			return math.floor(configured)
		end
		return 32
	end

	-- Returns the batch size used to partition flow separation work across actors.
	function MovementService:_GetFlowSeparationParallelBatchSize(): number
		local config = CombatMovementConfig.FLOW_SOFT_SEPARATION
		local configured = config and config.ParallelVelocityBatchSize or nil
		if type(configured) == "number" and configured > 0 then
			return math.floor(configured)
		end
		return 8
	end

	-- Returns the maximum in-flight time allowed for the managed parallel job.
	function MovementService:_GetFlowSeparationParallelMaxInFlightSeconds(): number
		local config = CombatMovementConfig.FLOW_SOFT_SEPARATION
		local configured = config and config.ParallelAsyncMaxInFlightSeconds or nil
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
	function MovementService:_GetOrCreateFlowSeparationRunner(): Result.Result<TParallelRunnerLike>
		local runner = self._flowSeparationParallelRunner
		if runner then
			return Ok(runner)
		end

		runner = ParallelRunner.new({
			Name = "CombatFlowMovement",
			ActorCount = self:_GetFlowSeparationParallelActorCount(),
			DefaultBatchSize = self:_GetFlowSeparationParallelBatchSize(),
		})

		local registerResult = runner:RegisterJob({
			Job = require(script.Parent.Parallel.FlowSeparationSolveOperation),
			WorkerModule = script.Parent.Parallel.FlowSeparationSolveWorker,
			ManagerModule = script.Parent.Parallel.FlowSeparationSolveManager,
		})
		if not registerResult.success then
			return Err("MovementParallelRegisterFailed", Errors.MOVEMENT_PARALLEL_REGISTER_FAILED, {
				CauseType = registerResult.type,
				CauseMessage = registerResult.message,
			})
		end

		self._flowSeparationParallelRunner = runner
		return Ok(runner)
	end

	-- Builds the managed parallel job wrapper used for flow separation dispatch.
	function MovementService:_CreateFlowSeparationManagedJob(): Result.Result<TManagedJob>
		local runnerResult = self:_GetOrCreateFlowSeparationRunner()
		if not runnerResult.success then
			return runnerResult
		end
		local runner = runnerResult.value
		local job = runner:CreateManagedJob({
			JobName = "FlowSeparationSolve",
			BuildWorkerPayload = function(payload: TFlowSeparationDispatchPayload)
				return payload.WorkerPayload
			end,
			BuildManagerPayload = function(payload: TFlowSeparationDispatchPayload)
				return payload.ManagerPayload
			end,
			BuildRunRequest = function(payload: TFlowSeparationDispatchPayload)
				return payload.RunRequest
			end,
			GetSessionToken = function(_payload: TFlowSeparationDispatchPayload)
				return self._flowCurrentSessionUserId
			end,
			MaxInFlightSeconds = self:_GetFlowSeparationParallelMaxInFlightSeconds(),
			Policy = ManagedJobPolicies.StrictFreshOnly,
		})
		return Ok(job)
	end

	-- Lazily creates the managed job wrapper for the flow separation runner.
	function MovementService:_GetOrCreateFlowSeparationManagedJob(): Result.Result<TManagedJob>
		local job = self._flowSeparationManagedJob
		if not job then
			local jobResult = self:_CreateFlowSeparationManagedJob()
			if not jobResult.success then
				return jobResult
			end
			job = jobResult.value
			self._flowSeparationManagedJob = job
		end
		return Ok(job)
	end

	-- Prewarms the parallel runner outside the combat tick so actor hiring never yields during a frame.
	function MovementService:_PrimeFlowSeparationParallelRuntime()
		if not self:_IsFlowSeparationParallelEnabled() then
			return
		end

		local runnerResult = self:_GetOrCreateFlowSeparationRunner()
		if not runnerResult.success then
			Result.MentionError("Combat:MovementService", "Failed to prime flow separation runtime", {
				CauseType = runnerResult.type,
				CauseMessage = runnerResult.message,
			}, runnerResult.type)
		end
	end

	-- Resets the flow-infrastructure runtime without destroying shared objects.
	function MovementService:_ResetFlowInfrastructureRuntime()
		local job = self._flowSeparationManagedJob
		if job then
			job:Reset()
		end
		local runner = self._flowSeparationParallelRunner
		if runner then
			local clearSharedMemoryResult = runner:SetSharedMemory("FlowSeparationSolve", nil)
			if not clearSharedMemoryResult.success then
				Result.MentionError("Combat:MovementService", "Failed to clear flow separation shared memory", {
					CauseType = clearSharedMemoryResult.type,
					CauseMessage = clearSharedMemoryResult.message,
				}, "MovementParallelSharedMemoryFailed")
			end
		end
		self._flowStaticSharedMemory = nil
		self._flowStaticSharedMemoryPathfinder = nil

		self:_ReleaseFlowLatestParallelSolve()
		self:_ReleaseFlowDispatchedSeparationSnapshot()
		local frameState = self._flowFrameState
		if frameState then
			frameState:Reset()
		end
	end

	-- Destroys the parallel flow infrastructure and its cached frame-state objects.
	function MovementService:_DestroyFlowInfrastructure()
		local job = self._flowSeparationManagedJob
		if job then
			job:Destroy()
		end
		self._flowSeparationManagedJob = nil

		local runner = self._flowSeparationParallelRunner
		if runner then
			runner:Destroy()
		end
		self._flowSeparationParallelRunner = nil
		self._flowStaticSharedMemory = nil
		self._flowStaticSharedMemoryPathfinder = nil
		local staticSharedMemoryHandle = self._flowStaticSharedMemoryHandle
		if staticSharedMemoryHandle ~= nil then
			staticSharedMemoryHandle:Destroy()
		end
		self._flowStaticSharedMemoryHandle = nil

		self:_ReleaseFlowLatestParallelSolve()
		self:_ReleaseFlowDispatchedSeparationSnapshot()
		self:_DestroyFlowFrameState()
	end

	-- Polls the managed job and publishes the completed flow solve when available.
	function MovementService:_ConsumeCompletedFlowSeparationSolve(): Result.Result<boolean>
		local closeConsumeProfile = DebugPlus.begin(CONSUME_COMPLETED_SOLVE_PROFILE_TAG, MOVEMENT_PROFILING_ENABLED)
		local job = self._flowSeparationManagedJob
		if not job then
			closeConsumeProfile()
			return Ok(false)
		end

		-- Reject jobs that have not actually produced a completed result yet.
		local status = job:GetStatus()
		if not status.HasCompletedResult then
			closeConsumeProfile()
			return Ok(false)
		end

		local managedResult = job:PollCompleted(self._flowCurrentSessionUserId)
		if not managedResult then
			closeConsumeProfile()
			return Ok(false)
		end

		local function _BuildConsumeErrorData(branch: string, extraData: { [string]: any }?): { [string]: any }
			local errorData = {
				Branch = branch,
				RequestId = managedResult.RequestId,
				SessionToken = managedResult.SessionToken,
				HasPayload = managedResult.Payload ~= nil,
				HasRows = managedResult.Rows ~= nil,
				HasErr = managedResult.Err ~= nil,
				PipelineState = self:_GetFlowPipelineState(),
			}
			if extraData then
				for key, value in extraData do
					errorData[key] = value
				end
			end
			return errorData
		end

		if managedResult.Err then
			closeConsumeProfile()
			return Err("MovementParallelResultFailed:Result", Errors.MOVEMENT_PARALLEL_RESULT_FAILED, {
				Branch = "Result",
				RequestId = managedResult.RequestId,
				SessionToken = managedResult.SessionToken,
				HasPayload = managedResult.Payload ~= nil,
				HasRows = managedResult.Rows ~= nil,
				HasErr = managedResult.Err ~= nil,
				PipelineState = self:_GetFlowPipelineState(),
				CauseType = managedResult.Err.type,
				CauseMessage = managedResult.Err.message or tostring(managedResult.Err),
				CauseData = managedResult.Err.data,
			})
		end
		if not managedResult.Rows then
			closeConsumeProfile()
			return Err(
				"MovementParallelResultFailed:Rows",
				Errors.MOVEMENT_PARALLEL_RESULT_FAILED,
				_BuildConsumeErrorData("Rows")
			)
		end

		-- Validate that the completed result matches the snapshot we dispatched earlier.
		local payload = managedResult.Payload :: TFlowSeparationDispatchPayload?
		local actorKeys = payload and payload.ActorKeys
		local goalKeyByEntity = self._flowDispatchedGoalKeyByActorKey
		local frameState = self._flowDispatchedFrameState :: TFlowPublishedFrameState?
		local payloadMatchesDispatched = payload ~= nil and payload == self._flowDispatchPayload
		local hasActorKeys = actorKeys ~= nil
		local hasGoalKeyByEntity = goalKeyByEntity ~= nil
		local hasFrameState = frameState ~= nil
		if
			not payloadMatchesDispatched
			or not hasActorKeys
			or not hasGoalKeyByEntity
			or not hasFrameState
		then
			closeConsumeProfile()
			return Err(
				"MovementParallelResultFailed:Payload",
				Errors.MOVEMENT_PARALLEL_RESULT_FAILED,
				_BuildConsumeErrorData("Payload", {
					PayloadMatchesDispatched = payloadMatchesDispatched,
					HasActorKeys = hasActorKeys,
					HasGoalKeyByEntity = hasGoalKeyByEntity,
					HasFrameState = hasFrameState,
				})
			)
		end

		local resolvedPayload = payload :: TFlowSeparationDispatchPayload
		local resolvedActorKeys = actorKeys :: { string }
		local resolvedGoalKeyByEntity = goalKeyByEntity :: { [string]: string }
		local resolvedFrameState = frameState :: TFlowPublishedFrameState

		-- Publish the solve outputs into the reusable frame caches.
		self:_ReleaseFlowLatestParallelSolve()

		local velocityByEntity = self:_ApplyFlowVelocityRows(
			resolvedActorKeys,
			managedResult.Rows :: { TFlowSeparationSolveRow },
			self._flowPublishedVelocityByActorKey,
			self._flowPublishedTouchedSettledNeighborByActorKey
		)
		local publishedVelocityCount = _CountEntries(velocityByEntity)
		if publishedVelocityCount == 0 then
			self:_ReleaseFlowDispatchedSeparationSnapshot()
			closeConsumeProfile()
			return Err(
				"MovementParallelResultFailed:Next",
				Errors.MOVEMENT_PARALLEL_RESULT_FAILED,
				_BuildConsumeErrorData("Next", {
					PublishedVelocityCount = publishedVelocityCount,
					AppliedRowCount = publishedVelocityCount,
					RowCount = #managedResult.Rows,
				})
			)
		end

		-- Copy the per-entity goal, position, and settle state into published tables.
		local publishedGoalKeyByEntity = self._flowPublishedGoalKeyByActorKey
		table.clear(publishedGoalKeyByEntity)
		for entityId, goalKey in resolvedGoalKeyByEntity do
			publishedGoalKeyByEntity[entityId] = goalKey
		end

		local publishedGoalPositionByEntity = self._flowPublishedGoalPositionByActorKey
		table.clear(publishedGoalPositionByEntity)
		for entityId, goalPosition in resolvedFrameState.GoalPositionByEntity do
			publishedGoalPositionByEntity[entityId] = goalPosition
		end

		local publishedGoalWorldSampleByEntity = self._flowPublishedGoalWorldSampleByActorKey
		table.clear(publishedGoalWorldSampleByEntity)
		for entityId, goalWorldSample in resolvedFrameState.GoalWorldSampleByEntity do
			publishedGoalWorldSampleByEntity[entityId] = goalWorldSample
		end

		local publishedPositionByEntity = self._flowPublishedPositionByActorKey
		table.clear(publishedPositionByEntity)
		for entityId, position in resolvedFrameState.PositionByEntity do
			publishedPositionByEntity[entityId] = position
		end

		local publishedWalkSpeedByEntity = self._flowPublishedWalkSpeedByActorKey
		table.clear(publishedWalkSpeedByEntity)
		for entityId, walkSpeed in resolvedFrameState.WalkSpeedByEntity do
			publishedWalkSpeedByEntity[entityId] = walkSpeed
		end

		local publishedIsSettledByEntity = self._flowPublishedIsSettledByActorKey
		table.clear(publishedIsSettledByEntity)
		for entityId, isSettled in resolvedFrameState.IsSettledByEntity do
			if isSettled then
				publishedIsSettledByEntity[entityId] = true
			end
		end

		local publishedSolve = self._flowPublishedSolve :: TFlowPublishedSolve
		publishedSolve.TickId = resolvedPayload.RunRequest.Args.TickId
		self._flowLatestParallelSolve = publishedSolve
		self:_ReleaseFlowDispatchedSeparationSnapshot()
		closeConsumeProfile()
		return Ok(true)
	end

	-- Dispatches the flow separation solve when the runtime and workload are ready.
	function MovementService:_TryDispatchFlowSeparationSolve(
		payload: TFlowSeparationDispatchPayload
	): Result.Result<boolean>
		local closeTryDispatchProfile = DebugPlus.begin(TRY_DISPATCH_PROFILE_TAG, MOVEMENT_PROFILING_ENABLED)
		if not self:_IsFlowSeparationParallelEnabled() then
			closeTryDispatchProfile()
			return Ok(false)
		end
		if #payload.ActorKeys < self:_GetFlowVelocityParallelMinEntityCount() then
			closeTryDispatchProfile()
			return Ok(false)
		end

		local jobResult = self:_GetOrCreateFlowSeparationManagedJob()
		if not jobResult.success then
			closeTryDispatchProfile()
			return jobResult
		end
		local job = jobResult.value
		local status = job:GetStatus()
		if status.InFlight then
			closeTryDispatchProfile()
			return Ok(false)
		end

		local dispatchResult = fromPcall("MovementParallelDispatchFailed", function()
			return DebugPlus.profile(TRY_DISPATCH_MANAGED_DISPATCH_PROFILE_TAG, function()
				return job:Dispatch(payload)
			end, MOVEMENT_PROFILING_ENABLED)
		end)
		closeTryDispatchProfile()
		if not dispatchResult.success then
			return Err("MovementParallelDispatchFailed", Errors.MOVEMENT_PARALLEL_DISPATCH_FAILED, {
				CauseMessage = dispatchResult.message,
			})
		end
		return Ok(dispatchResult.value == "Dispatched")
	end

	-- Consumes the completed solve and returns the pipeline to idle.
	function MovementService:_PublishCompletedFlowSolve()
		local consumeResult = self:_ConsumeCompletedFlowSeparationSolve()
		if not consumeResult.success then
			Result.MentionError("Combat:MovementService", "Failed to consume flow separation solve", {
				CauseType = consumeResult.type,
				CauseMessage = consumeResult.message,
				CauseData = consumeResult.data,
			}, consumeResult.type)
			self:_ReleaseFlowDispatchedSeparationSnapshot()
			_TransitionFlowPipeline(self, "Idle")
			return
		end
		if not consumeResult.value then
			self:_ReleaseFlowDispatchedSeparationSnapshot()
			_TransitionFlowPipeline(self, "Idle")
			return
		end

		_TransitionFlowPipeline(self, "Idle")
	end

	-- Advances the staged flow runtime pipeline once per scheduler tick. Path runtime does not use these stages.
	function MovementService:_AdvanceFlowPipeline(services: TFlowSchedulerServices?)
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
				_TransitionFlowPipeline(self, "BuildingSnapshot")
				state = "BuildingSnapshot"
			end

			if state == "BuildingSnapshot" then
				if not self:_CanAdvanceFlowPipelineStage(services, state) then
					return
				end

				-- Build a new dispatch snapshot before handing work to the parallel runner.
				local closeBuildSnapshotProfile =
					DebugPlus.begin(PIPELINE_BUILDING_SNAPSHOT_PROFILE_TAG, MOVEMENT_PROFILING_ENABLED)
				local snapshot, goalKeyByEntity, frameState, actorKeys =
					self:_BuildFlowDispatchManagerPayload(tickId, self:_ResolveFlowDeltaTime(services))
				closeBuildSnapshotProfile()
				if not snapshot or not goalKeyByEntity or not frameState or not actorKeys then
					_TransitionFlowPipeline(self, "Idle")
					return
				end

				self:_ReleaseFlowDispatchedSeparationSnapshot()
				self._flowDispatchedSeparationSnapshot = snapshot
				self._flowDispatchedActorKeys = actorKeys
				self._flowDispatchedGoalKeyByActorKey = goalKeyByEntity
				self._flowDispatchedFrameState = frameState

				_TransitionFlowPipeline(self, "PreparingSharedPacket")
				state = "PreparingSharedPacket"
			end

			if state == "PreparingSharedPacket" then
				if not self:_CanAdvanceFlowPipelineStage(services, state) then
					return
				end

				local snapshot = self._flowDispatchedSeparationSnapshot
				if not snapshot then
					_TransitionFlowPipeline(self, "Idle")
					return
				end

				self:_EnsureFlowSeparationStaticSharedMemory(snapshot)
				if self._flowStaticSharedMemory == nil or self._flowStaticSharedMemoryPathfinder ~= self._flowWallKeyCachePathfinder then
					self:_ReleaseFlowDispatchedSeparationSnapshot()
					_TransitionFlowPipeline(self, "Idle")
					return
				end

				_TransitionFlowPipeline(self, "PreparingRunRequest")
				state = "PreparingRunRequest"
			end

			if state == "PreparingRunRequest" then
				if not self:_CanAdvanceFlowPipelineStage(services, state) then
					return
				end

				local snapshot = self._flowDispatchedSeparationSnapshot
				if not snapshot then
					self:_ReleaseFlowDispatchedSeparationSnapshot()
					_TransitionFlowPipeline(self, "Idle")
					return
				end

				local managerPayload = snapshot :: TFlowSeparationManagerPayload
				local actorKeys = self._flowDispatchedActorKeys
				if not actorKeys then
					self:_ReleaseFlowDispatchedSeparationSnapshot()
					_TransitionFlowPipeline(self, "Idle")
					return
				end

				local closePrepareRunRequestProfile =
					DebugPlus.begin(PIPELINE_PREPARING_RUN_REQUEST_PROFILE_TAG, MOVEMENT_PROFILING_ENABLED)
				local runRequest = self:_CreateFlowSeparationManagerRunRequest(managerPayload)
				self._flowDispatchPayload =
					self:_AssembleFlowSeparationDispatchPayload(
						actorKeys,
						nil,
						managerPayload,
						runRequest
					)
				closePrepareRunRequestProfile()
				if not self._flowDispatchPayload then
					self:_ReleaseFlowDispatchedSeparationSnapshot()
					_TransitionFlowPipeline(self, "Idle")
					return
				end

				_TransitionFlowPipeline(self, "Dispatching")
				state = "Dispatching"
			end

			if state == "Dispatching" then
				if not self:_CanAdvanceFlowPipelineStage(services, state) then
					return
				end

				-- Submit the prepared payload once the pipeline has a valid snapshot.
				local payload = self._flowDispatchPayload
				local didDispatch = false
				if payload then
					local closeDispatchProfile =
						DebugPlus.begin(PIPELINE_DISPATCHING_DISPATCH_PROFILE_TAG, MOVEMENT_PROFILING_ENABLED)
					local dispatchResult = self:_TryDispatchFlowSeparationSolve(payload)
					if dispatchResult.success then
						didDispatch = dispatchResult.value
					else
						Result.MentionError("Combat:MovementService", "Failed to dispatch flow separation solve", {
							CauseType = dispatchResult.type,
							CauseMessage = dispatchResult.message,
						}, dispatchResult.type)
					end
					closeDispatchProfile()
				end
				if not payload or not didDispatch then
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
				if not job then
					self:_ReleaseFlowDispatchedSeparationSnapshot()
					_TransitionFlowPipeline(self, "Idle")
					return
				end

				local status = job:GetStatus()
				if not status.HasCompletedResult then
					if status.InFlight then
						return
					end

					self:_ReleaseFlowDispatchedSeparationSnapshot()
					_TransitionFlowPipeline(self, "Idle")
					return
				end

				if not self:_CanAdvanceFlowPipelineStage(services, "Publishing") then
					return
				end

				_TransitionFlowPipeline(self, "Publishing")
				self:_PublishCompletedFlowSolve()
			end
		end, MOVEMENT_PROFILING_ENABLED)
	end
end
