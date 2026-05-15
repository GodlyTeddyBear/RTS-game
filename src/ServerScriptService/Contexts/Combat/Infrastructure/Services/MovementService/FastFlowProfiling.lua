--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CombatMovementConfig = require(ReplicatedStorage.Contexts.Combat.Config.CombatMovementConfig)
local MovementTypes = require(script.Parent.Types)

type TFastFlowProfileCounters = MovementTypes.TFastFlowProfileCounters

return function(MovementService: any)
function MovementService:_IsFastFlowProfilingEnabled(): boolean
	local profileConfig = CombatMovementConfig.FASTFLOW_PROFILING
	return profileConfig ~= nil and profileConfig.Enabled == true
end


function MovementService:_ResetFastFlowProfileCounters()
	if not self:_IsFastFlowProfilingEnabled() then
		self._fastFlowProfileCounters = nil
		return
	end

	self._fastFlowProfileCounters = {
		SharedFieldCreations = 0,
		SharedFieldRefreshes = 0,
		MergeAttempts = 0,
		TrackedFlowEntities = 0,
		ActiveSeparationEntities = 0,
		DenseCellsEncountered = 0,
		DenseCellFallbackActivations = 0,
		DirtyEntitiesProcessed = 0,
		DirtyCellsProcessed = 0,
		LocalPairSolves = 0,
		BucketMembershipUpdates = 0,
		CachedRootPartHits = 0,
		CachedRootPartMisses = 0,
		CachedHumanoidHits = 0,
		CachedHumanoidMisses = 0,
		SpatialRefreshCalls = 0,
		CoveredCellRecomputes = 0,
		NearGoalBandRecomputes = 0,
		DirtyMarksTriggered = 0,
		DirtyMarksSkipped = 0,
		ParallelPairDispatches = 0,
		ParallelPairsDispatched = 0,
		ParallelPairRowsApplied = 0,
		ParallelPairSnapshotBuilds = 0,
		ParallelPairSnapshotEntities = 0,
		ParallelPairSnapshotPairs = 0,
		ParallelPairSnapshotBuildMilliseconds = 0,
		ParallelPairSnapshotAsyncDispatches = 0,
		ParallelPairSnapshotAsyncCompleted = 0,
		ParallelPairSnapshotAsyncApplied = 0,
		ParallelPairSnapshotAsyncStaleResults = 0,
		ParallelPairSnapshotAsyncDroppedResults = 0,
		ParallelPairSnapshotAsyncInFlightSkips = 0,
		ParallelPairSnapshotAsyncErrorFallbacks = 0,
		ParallelPairBelowThresholdSkips = 0,
		ParallelPairFailedFallbacks = 0,
		ParallelPairAsyncErrorFallbacks = 0,
		ParallelVelocityDispatches = 0,
		ParallelVelocityEntitiesDispatched = 0,
		ParallelVelocityRowsApplied = 0,
		ParallelVelocityAsyncDispatches = 0,
		ParallelVelocityAsyncCompleted = 0,
		ParallelVelocityAsyncApplied = 0,
		ParallelVelocityAsyncStaleResults = 0,
		ParallelVelocityAsyncDroppedResults = 0,
		ParallelVelocityAsyncInFlightSkips = 0,
		ParallelVelocityAsyncErrorFallbacks = 0,
		ParallelFallbacks = 0,
		ParallelAsyncDispatches = 0,
		ParallelAsyncCompleted = 0,
		ParallelAsyncApplied = 0,
		ParallelAsyncStaleResults = 0,
		ParallelAsyncDroppedResults = 0,
		ParallelAsyncInFlightSkips = 0,
	}
end


function MovementService:_IncrementFastFlowProfileCounter(counterKey: string, amount: number?)
	local counters = self._fastFlowProfileCounters
	if counters == nil then
		return
	end

	counters[counterKey] += if amount ~= nil then amount else 1
end


function MovementService:_SetFastFlowProfileCounter(counterKey: string, value: number)
	local counters = self._fastFlowProfileCounters
	if counters == nil then
		return
	end

	counters[counterKey] = value
end


function MovementService:_EmitFastFlowProfileCounters()
	local counters = self._fastFlowProfileCounters
	if counters == nil then
		return
	end

	local profileConfig = CombatMovementConfig.FASTFLOW_PROFILING
	local logInterval = if profileConfig ~= nil and type(profileConfig.LogIntervalSeconds) == "number"
		then math.max(0.25, profileConfig.LogIntervalSeconds)
		else 1
	local now = os.clock()
	if now - self._lastFastFlowProfileLogAt < logInterval then
		return
	end

	self._lastFastFlowProfileLogAt = now
	warn(string.format(
		"FastFlow profile | sharedCreates=%d sharedRefreshes=%d merges=%d tracked=%d activeSeparation=%d dirtyEntities=%d dirtyCells=%d localPairs=%d parallelDispatches=%d parallelPairs=%d parallelRows=%d pairSnapshots=%d pairSnapshotEntities=%d pairSnapshotPairs=%d pairSnapshotMs=%.3f pairSnapshotAsyncDispatches=%d pairSnapshotAsyncCompleted=%d pairSnapshotAsyncApplied=%d pairSnapshotAsyncStale=%d pairSnapshotAsyncDropped=%d pairSnapshotAsyncInFlightSkips=%d pairSnapshotAsyncErrorFallbacks=%d pairBelowThreshold=%d pairFailedFallbacks=%d pairAsyncErrorFallbacks=%d velocityDispatches=%d velocityEntities=%d velocityRows=%d velocityAsyncDispatches=%d velocityAsyncCompleted=%d velocityAsyncApplied=%d velocityAsyncStale=%d velocityAsyncDropped=%d velocityAsyncInFlightSkips=%d velocityAsyncErrorFallbacks=%d parallelFallbacks=%d asyncDispatches=%d asyncCompleted=%d asyncApplied=%d asyncStale=%d asyncDropped=%d asyncInFlightSkips=%d bucketUpdates=%d rootHits=%d rootMisses=%d humanoidHits=%d humanoidMisses=%d spatialRefreshes=%d cellRecomputes=%d nearGoalRecomputes=%d dirtyTriggered=%d dirtySkipped=%d denseCells=%d denseFallbacks=%d",
		counters.SharedFieldCreations,
		counters.SharedFieldRefreshes,
		counters.MergeAttempts,
		counters.TrackedFlowEntities,
		counters.ActiveSeparationEntities,
		counters.DirtyEntitiesProcessed,
		counters.DirtyCellsProcessed,
		counters.LocalPairSolves,
		counters.ParallelPairDispatches,
		counters.ParallelPairsDispatched,
		counters.ParallelPairRowsApplied,
		counters.ParallelPairSnapshotBuilds,
		counters.ParallelPairSnapshotEntities,
		counters.ParallelPairSnapshotPairs,
		counters.ParallelPairSnapshotBuildMilliseconds,
		counters.ParallelPairSnapshotAsyncDispatches,
		counters.ParallelPairSnapshotAsyncCompleted,
		counters.ParallelPairSnapshotAsyncApplied,
		counters.ParallelPairSnapshotAsyncStaleResults,
		counters.ParallelPairSnapshotAsyncDroppedResults,
		counters.ParallelPairSnapshotAsyncInFlightSkips,
		counters.ParallelPairSnapshotAsyncErrorFallbacks,
		counters.ParallelPairBelowThresholdSkips,
		counters.ParallelPairFailedFallbacks,
		counters.ParallelPairAsyncErrorFallbacks,
		counters.ParallelVelocityDispatches,
		counters.ParallelVelocityEntitiesDispatched,
		counters.ParallelVelocityRowsApplied,
		counters.ParallelVelocityAsyncDispatches,
		counters.ParallelVelocityAsyncCompleted,
		counters.ParallelVelocityAsyncApplied,
		counters.ParallelVelocityAsyncStaleResults,
		counters.ParallelVelocityAsyncDroppedResults,
		counters.ParallelVelocityAsyncInFlightSkips,
		counters.ParallelVelocityAsyncErrorFallbacks,
		counters.ParallelFallbacks,
		counters.ParallelAsyncDispatches,
		counters.ParallelAsyncCompleted,
		counters.ParallelAsyncApplied,
		counters.ParallelAsyncStaleResults,
		counters.ParallelAsyncDroppedResults,
		counters.ParallelAsyncInFlightSkips,
		counters.BucketMembershipUpdates,
		counters.CachedRootPartHits,
		counters.CachedRootPartMisses,
		counters.CachedHumanoidHits,
		counters.CachedHumanoidMisses,
		counters.SpatialRefreshCalls,
		counters.CoveredCellRecomputes,
		counters.NearGoalBandRecomputes,
		counters.DirtyMarksTriggered,
		counters.DirtyMarksSkipped,
		counters.DenseCellsEncountered,
		counters.DenseCellFallbackActivations
	))
end


function MovementService:_CountTableEntries(source: { [any]: any }): number
	local count = 0
	for _ in source do
		count += 1
	end
	return count
end

end
