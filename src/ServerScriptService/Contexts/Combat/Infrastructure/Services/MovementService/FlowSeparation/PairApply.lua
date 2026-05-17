--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Promise = require(ReplicatedStorage.Packages.Promise)
local ParallelQuery = require(ReplicatedStorage.Utilities.ParallelQuery)
local MovementTypes = require(script.Parent.Parent.Types)
local FlowSeparationTypes = require(script.Parent.Types)

local BeginManagedRequest = ParallelQuery.BeginManagedRequest
local CompleteManagedRequest = ParallelQuery.CompleteManagedRequest
local ConsumeLatestManagedResult = ParallelQuery.ConsumeLatestManagedResult
local ResultApplication = ParallelQuery.ResultApplication
local SharedMemoryAuthoring = ParallelQuery.SharedMemoryAuthoring
local ValidationHelpers = ParallelQuery.ValidationHelpers

type TFlowSeparationPairSnapshotBuildInput = MovementTypes.TFlowSeparationPairSnapshotBuildInput
type TFlowSeparationPairSnapshot = FlowSeparationTypes.TFlowSeparationPairSnapshot
type TFlowSeparationPairRows = FlowSeparationTypes.TFlowSeparationPairRows
type TManagedAsyncResult = FlowSeparationTypes.TManagedAsyncResult

local FLOW_SEPARATION_PAIR_SNAPSHOT_OPERATION_NAME = "FlowSeparationPairSnapshotBuild"

return function(MovementService: any)
	function MovementService:_CreateFlowSeparationSharedMemory(snapshot: TFlowSeparationPairSnapshot): SharedTable
		local builder = SharedMemoryAuthoring.CreateSnapshotBuilder()
		SharedMemoryAuthoring.SetArrayValues(builder, "PositionX", snapshot.PositionX)
		SharedMemoryAuthoring.SetArrayValues(builder, "PositionY", snapshot.PositionY)
		SharedMemoryAuthoring.SetArrayValues(builder, "Radius", snapshot.Radius)
		SharedMemoryAuthoring.SetArrayValues(builder, "PairA", snapshot.PairA)
		SharedMemoryAuthoring.SetArrayValues(builder, "PairB", snapshot.PairB)
		SharedMemoryAuthoring.SetScalar(builder, "KForce", snapshot.KForce)
		SharedMemoryAuthoring.SetScalar(builder, "MinSeparationDistance", snapshot.MinSeparationDistance)
		return SharedMemoryAuthoring.BuildSharedMemory(builder)
	end

	function MovementService:_CompleteFlowSeparationPairSnapshotBuildAsyncRequest(
		result: TManagedAsyncResult
	)
		local state = self._flowSeparationPairSnapshotBuildAsyncState
		if not state then
			return
		end

		local completionStatus = CompleteManagedRequest(state, result)
		if completionStatus == "StaleRequest" then
			self:_IncrementFastFlowProfileCounter("ParallelPairSnapshotAsyncStaleResults")
			return
		end

		if completionStatus == "ReplacedPrevious" then
			self:_IncrementFastFlowProfileCounter("ParallelPairSnapshotAsyncDroppedResults")
		end
	end

	function MovementService:_DispatchFlowSeparationPairSnapshotBuildAsync(
		input: TFlowSeparationPairSnapshotBuildInput,
		sepConfig: any
	): "Dispatched" | "InFlight" | "BelowThreshold" | "Failed"
		local candidateCellCount = #input.CandidateCellKeys
		if candidateCellCount < self:_GetFlowSeparationParallelSnapshotBuildMinCandidateCount(sepConfig) then
			return "BelowThreshold"
		end

		if self:_HasFlowSeparationPairSnapshotBuildAsyncRequestInFlight(sepConfig) then
			self:_IncrementFastFlowProfileCounter("ParallelPairSnapshotAsyncInFlightSkips")
			return "InFlight"
		end

		local runtime = self:_GetOrCreateFlowSeparationRuntime()
		local sessionUserId = runtime.SessionUserId
		local state = self:_GetOrCreateFlowSeparationPairSnapshotBuildAsyncState()
		local dispatchStatus, requestId =
			BeginManagedRequest(state, sessionUserId, nil, self:_GetFlowSeparationParallelAsyncMaxInFlightSeconds(sepConfig))
		if dispatchStatus == "InFlight" then
			self:_IncrementFastFlowProfileCounter("ParallelPairSnapshotAsyncInFlightSkips")
			return "InFlight"
		end

		local promise: typeof(Promise.new(function() end))? = nil
		local ok = pcall(function()
			local runner = self:_GetOrCreateFlowSeparationParallelRunner(sepConfig)
			local batchSize = self:_GetFlowSeparationParallelSnapshotBuildBatchSize(sepConfig)
			runner:SetLocalMemory(
				FLOW_SEPARATION_PAIR_SNAPSHOT_OPERATION_NAME,
				self:_CreateFlowSeparationPairSnapshotBuildSharedMemory(input)
			)
			promise = runner:RunAsync(FLOW_SEPARATION_PAIR_SNAPSHOT_OPERATION_NAME, {
				WorkCount = #input.TaskCellIndices,
				BatchSize = batchSize,
				TimeoutSeconds = self:_GetFlowSeparationParallelSnapshotBuildTimeoutSeconds(sepConfig),
			})
		end)

		if not (ok and promise) then
			state.InFlight = false
			state.InFlightRequestId = nil
			state.InFlightSessionToken = nil
			state.LastDispatchClock = 0
			self:_IncrementFastFlowProfileCounter("ParallelFallbacks")
			self:_IncrementFastFlowProfileCounter("ParallelPairSnapshotAsyncErrorFallbacks")
			return "Failed"
		end

		promise:andThen(function(resultRows)
			self:_CompleteFlowSeparationPairSnapshotBuildAsyncRequest({
				RequestId = requestId :: number,
				SessionToken = sessionUserId,
				Payload = input,
				Rows = resultRows :: any,
				Err = nil,
				CompletedClock = os.clock(),
			})
		end):catch(function(resultErr)
			self:_CompleteFlowSeparationPairSnapshotBuildAsyncRequest({
				RequestId = requestId :: number,
				SessionToken = sessionUserId,
				Payload = input,
				Rows = nil,
				Err = resultErr,
				CompletedClock = os.clock(),
			})
		end)

		self:_IncrementFastFlowProfileCounter("ParallelPairSnapshotAsyncDispatches")
		return "Dispatched"
	end

	function MovementService:_ApplyCompletedFlowSeparationPairSnapshotBuildAsyncResult(
		sepConfig: any
	): TFlowSeparationPairSnapshot?
		local state = self._flowSeparationPairSnapshotBuildAsyncState
		if not (state and state.LatestCompletedResult) then
			return
		end

		self:_IncrementFastFlowProfileCounter("ParallelPairSnapshotAsyncCompleted")

		local runtime = self:_GetOrCreateFlowSeparationRuntime()
		local managedResult, consumeStatus = ConsumeLatestManagedResult(state, runtime.SessionUserId)
		if consumeStatus == "NoResult" then
			return
		end

		if consumeStatus == "StaleRequest" or consumeStatus == "SessionMismatch" then
			self:_IncrementFastFlowProfileCounter("ParallelPairSnapshotAsyncStaleResults")
			return
		end

		if not managedResult then
			return
		end

		local input = managedResult.Payload :: TFlowSeparationPairSnapshotBuildInput
		if managedResult.Err or not managedResult.Rows then
			self:_IncrementFastFlowProfileCounter("ParallelFallbacks")
			self:_IncrementFastFlowProfileCounter("ParallelPairSnapshotAsyncErrorFallbacks")
			self:_MarkFlowSeparationBuildInputDirty(input)
			return
		end

		local snapshot, didOverflow = self:_BuildFlowSeparationPairSnapshotFromBuildInput(input, managedResult.Rows :: any)
		if didOverflow then
			self:_IncrementFastFlowProfileCounter("ParallelFallbacks")
			self:_IncrementFastFlowProfileCounter("ParallelPairSnapshotAsyncErrorFallbacks")
			self:_MarkFlowSeparationBuildInputDirty(input)
			return
		end

		if snapshot then
			self:_IncrementFastFlowProfileCounter("ParallelPairSnapshotAsyncApplied")
		end
		return snapshot
	end

	function MovementService:_ApplyFlowSeparationPairDelta(
		snapshot: TFlowSeparationPairSnapshot,
		entityIndex: number,
		delta: Vector2,
		scaleDelta: boolean?
	)
		local entityId = snapshot.EntityIds[entityIndex]
		if not entityId then
			return
		end

		local runtime = self:_GetOrCreateFlowSeparationRuntime()
		local entityState = runtime.EntityStateById[entityId]
		if not entityState then
			return
		end

		local nearGoalScale = if scaleDelta == true then entityState.NearGoalScale else 1
		entityState.Separation += delta * nearGoalScale
	end

	function MovementService:_ApplyFlowSeparationPairRows(
		snapshot: TFlowSeparationPairSnapshot,
		rows: TFlowSeparationPairRows,
		scaleDeltas: boolean?
	)
		ResultApplication.ApplyRows({
			Rows = rows,
			ValidateRow = function(row)
				local indexValidation = ValidationHelpers.RequireIndexFields(
					row,
					{ "EntityIndexA", "EntityIndexB" },
					#snapshot.EntityIds
				)
				if not indexValidation.IsValid then
					return indexValidation
				end

				return ValidationHelpers.RequireNumberFields(row, { "DeltaAX", "DeltaAY", "DeltaBX", "DeltaBY" })
			end,
			ResolveTarget = function(row)
				local _entityA, _entityB, entityIndexA, entityIndexB =
					ResultApplication.ResolveIndexedPair(row, "EntityIndexA", "EntityIndexB", snapshot.EntityIds)
				if not entityIndexA or not entityIndexB then
					return
				end

				return {
					EntityIndexA = entityIndexA,
					EntityIndexB = entityIndexB,
				}
			end,
			ApplyRow = function(resolvedPair, row)
				self:_ApplyFlowSeparationPairDelta(
					snapshot,
					resolvedPair.EntityIndexA,
					Vector2.new(row.DeltaAX, row.DeltaAY),
					scaleDeltas
				)
				self:_ApplyFlowSeparationPairDelta(
					snapshot,
					resolvedPair.EntityIndexB,
					Vector2.new(row.DeltaBX, row.DeltaBY),
					scaleDeltas
				)
				if row.DeltaAX ~= 0 or row.DeltaAY ~= 0 or row.DeltaBX ~= 0 or row.DeltaBY ~= 0 then
					self:_IncrementFastFlowProfileCounter("ParallelPairRowsApplied")
				end
			end,
		})
	end

	function MovementService:_ApplyCompletedFlowSeparationPairAsyncResult(sepConfig: any)
		local job = self._flowSeparationPairManagedJob
		if not job then
			return
		end

		local status = self:_ObserveFlowSeparationPairManagedJob(job)
		if not status.HasCompletedResult then
			return
		end

		local runtime = self:_GetOrCreateFlowSeparationRuntime()
		self:_IncrementFastFlowProfileCounter("ParallelAsyncCompleted")
		local managedResult = job:PollCompleted(runtime.SessionUserId)
		if not managedResult then
			self:_IncrementFastFlowProfileCounter("ParallelAsyncStaleResults")
			return
		end

		local snapshot = managedResult.Payload :: TFlowSeparationPairSnapshot
		if managedResult.Err or not managedResult.Rows then
			self:_IncrementFastFlowProfileCounter("ParallelFallbacks")
			self:_IncrementFastFlowProfileCounter("ParallelPairAsyncErrorFallbacks")
			self:_MarkFlowSeparationSnapshotDirty(snapshot)
			return
		end

		self:_ApplyFlowSeparationPairRows(snapshot, managedResult.Rows :: any, true)
		self:_IncrementFastFlowProfileCounter("ParallelAsyncApplied")
	end

	function MovementService:_DispatchFlowSeparationPairsWithParallelQueryAsync(
		snapshot: TFlowSeparationPairSnapshot,
		sepConfig: any
	): "Dispatched" | "InFlight" | "BelowThreshold" | "Failed"
		local pairCount = #snapshot.PairA
		if pairCount < self:_GetFlowSeparationParallelMinPairCount(sepConfig) then
			self:_IncrementFastFlowProfileCounter("ParallelPairBelowThresholdSkips")
			return "BelowThreshold"
		end

		local job = self:_GetOrCreateFlowSeparationPairManagedJob(sepConfig)
		local status = self:_ObserveFlowSeparationPairManagedJob(job)
		if status.InFlight then
			return "InFlight"
		end

		local ok, dispatchStatus = pcall(function()
			return job:Dispatch(snapshot)
		end)
		if not ok then
			self:_IncrementFastFlowProfileCounter("ParallelFallbacks")
			self:_IncrementFastFlowProfileCounter("ParallelPairFailedFallbacks")
			return "Failed"
		end

		if dispatchStatus == "InFlight" then
			return "InFlight"
		end

		self:_IncrementFastFlowProfileCounter("ParallelPairDispatches")
		self:_IncrementFastFlowProfileCounter("ParallelPairsDispatched", pairCount)
		self:_IncrementFastFlowProfileCounter("ParallelAsyncDispatches")
		return "Dispatched"
	end

	function MovementService:_ResolveFlowSeparationPairSnapshot(
		pairSnapshot: TFlowSeparationPairSnapshot,
		sepConfig: any,
		_scaleDeltasOnSync: boolean?
	)
		if #pairSnapshot.PairA == 0 then
			return
		end

		if not self:_IsFlowSeparationParallelEnabled(sepConfig) or not self:_IsFlowSeparationParallelAsyncEnabled(sepConfig) then
			self:_MarkFlowSeparationSnapshotDirty(pairSnapshot)
			return
		end

		local asyncStatus = self:_DispatchFlowSeparationPairsWithParallelQueryAsync(pairSnapshot, sepConfig)
		if asyncStatus == "Failed" then
			self:_MarkFlowSeparationSnapshotDirty(pairSnapshot)
		end
	end
end
