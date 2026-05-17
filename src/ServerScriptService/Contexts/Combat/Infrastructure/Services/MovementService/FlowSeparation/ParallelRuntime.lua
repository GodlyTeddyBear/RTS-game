--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ParallelQuery = require(ReplicatedStorage.Utilities.ParallelQuery)
local MovementTypes = require(script.Parent.Parent.Types)
local FlowSeparationTypes = require(script.Parent.Types)

local ManagedJobPolicies = ParallelQuery.ManagedJobPolicies
local CreateManagedAsyncState = ParallelQuery.CreateManagedAsyncState
local ExpireManagedInFlightRequest = ParallelQuery.ExpireManagedInFlightRequest

type TFlowSeparationPairSnapshotBuildAsyncState = MovementTypes.TFlowSeparationPairSnapshotBuildAsyncState
type TFlowSeparationPairSnapshot = FlowSeparationTypes.TFlowSeparationPairSnapshot
type TManagedJob = FlowSeparationTypes.TManagedJob

local FLOW_SEPARATION_PAIR_OPERATION_NAME = "FlowSeparationPair"

return function(MovementService: any)
	function MovementService:_GetOrCreateFlowSeparationParallelRunner(sepConfig: any)
		local runner = self._flowSeparationParallelRunner
		if runner then
			return runner
		end

		runner = ParallelQuery.new({
			Name = "CombatFlowSeparation",
			ActorCount = self:_GetFlowSeparationParallelActorCount(sepConfig),
			Operations = {
				script.Parent.Parent.Parallel.FlowSeparationPairOperation,
				script.Parent.Parent.Parallel.FlowSeparationPairSnapshotOperation,
				script.Parent.Parent.Parallel.FlowVelocitySolveOperation,
			},
		})
		self._flowSeparationParallelRunner = runner
		return runner
	end

	function MovementService:_DestroyFlowSeparationParallelRunner()
		local runner = self._flowSeparationParallelRunner
		if not runner then
			return
		end

		runner:Destroy()
		self._flowSeparationParallelRunner = nil
		self._flowSeparationPairManagedJob = nil
		self._flowSeparationPairManagedJobLastObservedError = nil
		self._flowVelocityManagedJob = nil
		self._flowVelocityManagedJobLastObservedError = nil
	end

	function MovementService:_CreateFlowSeparationPairManagedJob(sepConfig: any): TManagedJob
		local runner = self:_GetOrCreateFlowSeparationParallelRunner(sepConfig)
		return runner:CreateManagedJob({
			OperationName = FLOW_SEPARATION_PAIR_OPERATION_NAME,
			BuildLocalMemory = function(snapshot: TFlowSeparationPairSnapshot)
				return self:_CreateFlowSeparationSharedMemory(snapshot)
			end,
			BuildRunRequest = function(snapshot: TFlowSeparationPairSnapshot)
				return {
					WorkCount = #snapshot.PairA,
					BatchSize = self:_GetFlowSeparationParallelBatchSize(sepConfig),
					TimeoutSeconds = self:_GetFlowSeparationParallelTimeoutSeconds(sepConfig),
				}
			end,
			GetSessionToken = function(_snapshot: TFlowSeparationPairSnapshot)
				local runtime = self:_GetOrCreateFlowSeparationRuntime()
				return runtime.SessionUserId
			end,
			MaxInFlightSeconds = self:_GetFlowSeparationParallelAsyncMaxInFlightSeconds(sepConfig),
			Policy = ManagedJobPolicies.StrictFreshOnly,
		})
	end

	function MovementService:_GetOrCreateFlowSeparationPairManagedJob(sepConfig: any): TManagedJob
		local job = self._flowSeparationPairManagedJob
		if not job then
			job = self:_CreateFlowSeparationPairManagedJob(sepConfig)
			self._flowSeparationPairManagedJob = job
		end
		return job
	end

	function MovementService:_ObserveFlowSeparationPairManagedJob(job: TManagedJob)
		local status = job:GetStatus()
		if status.LastError ~= self._flowSeparationPairManagedJobLastObservedError then
			self._flowSeparationPairManagedJobLastObservedError = status.LastError
			if type(status.LastError) == "table" and status.LastError.Kind == "Timeout" then
				self:_IncrementFastFlowProfileCounter("ParallelFallbacks")
				self:_IncrementFastFlowProfileCounter("ParallelAsyncDroppedResults")
			end
		end

		return status
	end

	function MovementService:_CreateFlowSeparationPairSnapshotBuildAsyncState(): TFlowSeparationPairSnapshotBuildAsyncState
		return CreateManagedAsyncState()
	end

	function MovementService:_GetOrCreateFlowSeparationPairSnapshotBuildAsyncState(): TFlowSeparationPairSnapshotBuildAsyncState
		local state = self._flowSeparationPairSnapshotBuildAsyncState
		if not state then
			state = self:_CreateFlowSeparationPairSnapshotBuildAsyncState()
			self._flowSeparationPairSnapshotBuildAsyncState = state
		end
		return state
	end

	function MovementService:_ClearFlowSeparationPairSnapshotBuildAsyncState()
		self._flowSeparationPairSnapshotBuildAsyncState = nil
	end

	function MovementService:_ExpireFlowSeparationPairSnapshotBuildAsyncRequestIfNeeded(sepConfig: any)
		local state = self._flowSeparationPairSnapshotBuildAsyncState
		if not (state and state.InFlight) then
			return
		end

		local maxInFlightSeconds = self:_GetFlowSeparationParallelAsyncMaxInFlightSeconds(sepConfig)
		local didExpire = ExpireManagedInFlightRequest(state, maxInFlightSeconds)
		if not didExpire then
			return
		end

		state.LatestCompletedResult = nil
		self:_IncrementFastFlowProfileCounter("ParallelFallbacks")
		self:_IncrementFastFlowProfileCounter("ParallelPairSnapshotAsyncDroppedResults")
	end

	function MovementService:_HasFlowSeparationPairSnapshotBuildAsyncRequestInFlight(sepConfig: any): boolean
		self:_ExpireFlowSeparationPairSnapshotBuildAsyncRequestIfNeeded(sepConfig)

		local state = self._flowSeparationPairSnapshotBuildAsyncState
		return (state and state.InFlight) or false
	end

	function MovementService:_HasFlowSeparationPairAsyncRequestInFlight(sepConfig: any): boolean
		local job = self._flowSeparationPairManagedJob
		if not job then
			return false
		end

		local status = self:_ObserveFlowSeparationPairManagedJob(job)
		return status.InFlight
	end
end
