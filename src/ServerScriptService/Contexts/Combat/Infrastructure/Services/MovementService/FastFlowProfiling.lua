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
		"FastFlow profile | sharedCreates=%d sharedRefreshes=%d merges=%d tracked=%d activeSeparation=%d dirtyEntities=%d dirtyCells=%d localPairs=%d bucketUpdates=%d rootHits=%d rootMisses=%d humanoidHits=%d humanoidMisses=%d spatialRefreshes=%d cellRecomputes=%d nearGoalRecomputes=%d dirtyTriggered=%d dirtySkipped=%d denseCells=%d denseFallbacks=%d",
		counters.SharedFieldCreations,
		counters.SharedFieldRefreshes,
		counters.MergeAttempts,
		counters.TrackedFlowEntities,
		counters.ActiveSeparationEntities,
		counters.DirtyEntitiesProcessed,
		counters.DirtyCellsProcessed,
		counters.LocalPairSolves,
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
