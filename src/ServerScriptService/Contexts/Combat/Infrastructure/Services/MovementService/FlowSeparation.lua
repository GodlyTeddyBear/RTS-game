--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Promise = require(ReplicatedStorage.Packages.Promise)
local CombatMovementConfig = require(ReplicatedStorage.Contexts.Combat.Config.CombatMovementConfig)
local BoidsConfig = require(ReplicatedStorage.Contexts.Combat.Config.BoidsConfig)
local ParallelQuery = require(ReplicatedStorage.Utilities.ParallelQuery)
local MovementTypes = require(script.Parent.Types)
local MovementMath = require(script.Parent.MovementMath)
local FlowSeparationPairSnapshotCodec = require(script.Parent.Parallel.FlowSeparationPairSnapshotCodec)
local FlowSeparationPairSnapshotSchema = require(script.Parent.Parallel.FlowSeparationPairSnapshotSchema)

type TFlowSeparationCoveredCell = MovementTypes.TFlowSeparationCoveredCell
type TFlowSeparationEntityState = MovementTypes.TFlowSeparationEntityState
type TFlowSeparationRuntime = MovementTypes.TFlowSeparationRuntime
type TFlowSeparationPairSnapshotBuildInput = MovementTypes.TFlowSeparationPairSnapshotBuildInput
type TFlowSeparationPairSnapshotBuildAsyncResult = MovementTypes.TFlowSeparationPairSnapshotBuildAsyncResult
type TFlowSeparationPairSnapshotBuildAsyncState = MovementTypes.TFlowSeparationPairSnapshotBuildAsyncState

local FLOW_SEPARATION_MATERIAL_MOVE_RATIO = 0.25
local FLOW_SEPARATION_PAIR_OPERATION_NAME = "FlowSeparationPair"
local FLOW_SEPARATION_PAIR_SNAPSHOT_OPERATION_NAME = "FlowSeparationPairSnapshotBuild"

type TFlowSeparationPairSnapshot = {
	EntityIds: { number },
	EntityIndexById: { [number]: number },
	PositionX: { [number]: number },
	PositionY: { [number]: number },
	Radius: { [number]: number },
	PairA: { [number]: number },
	PairB: { [number]: number },
	KForce: number,
	MinSeparationDistance: number,
}

type TFlowSeparationPairRows = { [number]: { [string]: any } }

type TFlowSeparationPairAsyncResult = {
	RequestId: number,
	SessionUserId: number?,
	Snapshot: TFlowSeparationPairSnapshot,
	Rows: TFlowSeparationPairRows?,
	Err: any?,
}

type TFlowSeparationPairAsyncState = {
	PendingRequestId: number,
	LatestAppliedRequestId: number,
	LatestCompletedResult: TFlowSeparationPairAsyncResult?,
	InFlight: boolean,
	InFlightRequestId: number?,
	InFlightSessionUserId: number?,
	LastDispatchClock: number,
}

return function(MovementService: any)
function MovementService:_GetFlowArrivalThreshold(): number
	local configuredThreshold = BoidsConfig.ArrivalThreshold
	if type(configuredThreshold) ~= "number" or configuredThreshold <= 0 then
		return 2.75
	end
	return configuredThreshold
end


function MovementService:_GetFlowClumpIdleRadiusStuds(sepConfig: any): number
	local configuredRadius = if sepConfig ~= nil then sepConfig.ClumpIdleRadiusStuds else nil
	if type(configuredRadius) == "number" and configuredRadius > 0 then
		return configuredRadius
	end
	return self:_GetFlowArrivalThreshold() * 2.5
end


function MovementService:_GetFlowClumpTouchPaddingStuds(sepConfig: any): number
	local configuredPadding = if sepConfig ~= nil then sepConfig.ClumpTouchDistancePaddingStuds else nil
	if type(configuredPadding) == "number" and configuredPadding >= 0 then
		return configuredPadding
	end
	return 0.5
end


function MovementService:_GetSharedFlowfieldRefreshCooldownSeconds(sepConfig: any): number
	local sharedFieldConfig = self:_GetFastFlowSharedFieldConfig()
	local configuredCooldown = if sharedFieldConfig ~= nil then sharedFieldConfig.RefreshCooldownSeconds else nil
	if type(configuredCooldown) == "number" and configuredCooldown > 0 then
		return configuredCooldown
	end

	configuredCooldown = if sepConfig ~= nil then sepConfig.SharedFlowfieldRefreshCooldownSeconds else nil
	if type(configuredCooldown) == "number" and configuredCooldown > 0 then
		return configuredCooldown
	end
	return 0.35
end


function MovementService:_UsePrunedSharedGeneration(): boolean
	local sharedFieldConfig = self:_GetFastFlowSharedFieldConfig()
	return sharedFieldConfig ~= nil and sharedFieldConfig.UsePrunedGeneration == true
end


function MovementService:_AllowSingleSharedRefreshPerCooldown(): boolean
	local sharedFieldConfig = self:_GetFastFlowSharedFieldConfig()
	return sharedFieldConfig == nil or sharedFieldConfig.AllowSingleRefreshPerCooldown ~= false
end


function MovementService:_GetSharedRepresentativeStartCap(): number
	local sharedFieldConfig = self:_GetFastFlowSharedFieldConfig()
	local configuredCap = if sharedFieldConfig ~= nil then sharedFieldConfig.RepresentativeStartCap else nil
	if type(configuredCap) == "number" and configuredCap > 0 then
		return math.max(1, math.floor(configuredCap))
	end
	return 8
end


function MovementService:_GetIsolationSkipRadiusStuds(sepConfig: any): number
	local configuredRadius = if sepConfig ~= nil then sepConfig.IsolationSkipRadiusStuds else nil
	if type(configuredRadius) == "number" and configuredRadius > 0 then
		return configuredRadius
	end
	return 6
end


function MovementService:_UseIsolationSkip(sepConfig: any): boolean
	return sepConfig ~= nil and sepConfig.IsolationSkipEnabled == true
end


function MovementService:_UseDenseCellFallback(sepConfig: any): boolean
	return false
end


function MovementService:_GetDenseCellOccupancyThreshold(sepConfig: any): number
	local configuredThreshold = if sepConfig ~= nil then sepConfig.DenseCellOccupancyThreshold else nil
	if type(configuredThreshold) == "number" and configuredThreshold >= 2 then
		return math.max(2, math.floor(configuredThreshold))
	end
	return 10
end


function MovementService:_GetNearGoalSeparationScale(sepConfig: any): number
	local configuredScale = if sepConfig ~= nil then sepConfig.NearGoalSeparationScale else nil
	if type(configuredScale) == "number" and configuredScale >= 0 then
		return math.clamp(configuredScale, 0, 1)
	end
	return 0.35
end


function MovementService:_GetNearGoalSeparationRadiusStuds(sepConfig: any): number
	local configuredRadius = if sepConfig ~= nil then sepConfig.NearGoalSeparationRadiusStuds else nil
	if type(configuredRadius) == "number" and configuredRadius > 0 then
		return configuredRadius
	end
	return 8
end


function MovementService:_GetNeighborDirtyMoveThresholdStuds(sepConfig: any, cellWidthStuds: number): number
	local configuredThreshold = if sepConfig ~= nil then sepConfig.NeighborDirtyMoveThresholdStuds else nil
	if type(configuredThreshold) == "number" and configuredThreshold > 0 then
		return configuredThreshold
	end
	return math.max(0.5, cellWidthStuds * 0.5)
end


function MovementService:_IsFlowSeparationParallelEnabled(sepConfig: any): boolean
	return sepConfig ~= nil and sepConfig.ParallelEnabled == true
end


function MovementService:_GetFlowSeparationParallelActorCount(sepConfig: any): number
	local configuredActorCount = if sepConfig ~= nil then sepConfig.ParallelActorCount else nil
	if type(configuredActorCount) == "number" and configuredActorCount > 0 then
		return math.max(1, math.floor(configuredActorCount))
	end
	return 4
end


function MovementService:_GetFlowSeparationParallelBatchSize(sepConfig: any): number
	local configuredBatchSize = if sepConfig ~= nil then sepConfig.ParallelBatchSize else nil
	if type(configuredBatchSize) == "number" and configuredBatchSize > 0 then
		return math.max(1, math.floor(configuredBatchSize))
	end
	return 64
end


function MovementService:_GetFlowSeparationParallelMinPairCount(sepConfig: any): number
	local configuredMinPairCount = if sepConfig ~= nil then sepConfig.ParallelMinPairCount else nil
	if type(configuredMinPairCount) == "number" and configuredMinPairCount >= 1 then
		return math.max(1, math.floor(configuredMinPairCount))
	end
	return 1
end


function MovementService:_IsFlowSeparationParallelSnapshotBuildEnabled(sepConfig: any): boolean
	return self:_IsFlowSeparationParallelEnabled(sepConfig)
		and sepConfig ~= nil
		and sepConfig.ParallelSnapshotBuildEnabled ~= false
end


function MovementService:_GetFlowSeparationParallelSnapshotBuildMinCandidateCount(sepConfig: any): number
	local configuredMinCandidateCount = if sepConfig ~= nil then sepConfig.ParallelSnapshotBuildMinCandidateCount else nil
	if type(configuredMinCandidateCount) == "number" and configuredMinCandidateCount >= 1 then
		return math.max(1, math.floor(configuredMinCandidateCount))
	end
	return 1
end


function MovementService:_GetFlowSeparationParallelSnapshotBuildMaxPairsPerTask(sepConfig: any): number
	return FlowSeparationPairSnapshotSchema.GetFixedMaxPairsPerTask()
end


function MovementService:_GetFlowSeparationParallelSnapshotBuildMaxEntitiesPerTask(
	sepConfig: any,
	maxPairsPerTask: number
): number
	local configuredMaxEntitiesPerTask = if sepConfig ~= nil then sepConfig.ParallelSnapshotBuildMaxEntitiesPerTask else nil
	assert(type(maxPairsPerTask) == "number" and maxPairsPerTask > 0 and maxPairsPerTask % 1 == 0, "maxPairsPerTask must be a positive integer")
	assert(
		type(configuredMaxEntitiesPerTask) == "number"
			and configuredMaxEntitiesPerTask >= 2
			and configuredMaxEntitiesPerTask % 1 == 0,
		"FLOW_SOFT_SEPARATION.ParallelSnapshotBuildMaxEntitiesPerTask must be an integer >= 2"
	)
	return configuredMaxEntitiesPerTask
end


function MovementService:_GetFlowSeparationParallelSnapshotBuildOverflowMode(_sepConfig: any): "Chunk" | "Local"
	return "Chunk"
end


function MovementService:_GetFlowSeparationParallelSnapshotBuildBatchSize(sepConfig: any): number
	local configuredBatchSize = if sepConfig ~= nil then sepConfig.ParallelSnapshotBuildBatchSize else nil
	if type(configuredBatchSize) == "number" and configuredBatchSize > 0 then
		return math.max(1, math.floor(configuredBatchSize))
	end
	return 32
end


function MovementService:_GetFlowSeparationParallelSnapshotBuildTimeoutSeconds(sepConfig: any): number
	local configuredTimeout = if sepConfig ~= nil then sepConfig.ParallelSnapshotBuildTimeoutSeconds else nil
	if type(configuredTimeout) == "number" and configuredTimeout > 0 then
		return configuredTimeout
	end
	return 0.02
end


function MovementService:_GetFlowSeparationParallelTimeoutSeconds(sepConfig: any): number
	local configuredTimeout = if sepConfig ~= nil then sepConfig.ParallelTimeoutSeconds else nil
	if type(configuredTimeout) == "number" and configuredTimeout > 0 then
		return configuredTimeout
	end
	return 0.02
end


function MovementService:_GetFlowVelocityParallelBatchSize(sepConfig: any): number
	local configuredBatchSize = if sepConfig ~= nil then sepConfig.ParallelVelocityBatchSize else nil
	if type(configuredBatchSize) == "number" and configuredBatchSize > 0 then
		return math.max(1, math.floor(configuredBatchSize))
	end
	return 64
end


function MovementService:_GetFlowVelocityParallelMinEntityCount(sepConfig: any): number
	local configuredMinEntityCount = if sepConfig ~= nil then sepConfig.ParallelMinVelocityEntityCount else nil
	if type(configuredMinEntityCount) == "number" and configuredMinEntityCount >= 1 then
		return math.max(1, math.floor(configuredMinEntityCount))
	end
	return 1
end


function MovementService:_GetFlowVelocityParallelTimeoutSeconds(sepConfig: any): number
	local configuredTimeout = if sepConfig ~= nil then sepConfig.ParallelVelocityTimeoutSeconds else nil
	if type(configuredTimeout) == "number" and configuredTimeout > 0 then
		return configuredTimeout
	end
	return 0.02
end


function MovementService:_IsFlowSeparationParallelAsyncEnabled(sepConfig: any): boolean
	return self:_IsFlowSeparationParallelEnabled(sepConfig)
		and sepConfig ~= nil
		and sepConfig.ParallelAsyncEnabled ~= false
end


function MovementService:_GetFlowSeparationParallelAsyncMaxInFlightSeconds(sepConfig: any): number
	local configuredTimeout = if sepConfig ~= nil then sepConfig.ParallelAsyncMaxInFlightSeconds else nil
	if type(configuredTimeout) == "number" and configuredTimeout > 0 then
		return configuredTimeout
	end
	return 0.05
end


function MovementService:_ShouldUsePreviousFlowSeparationParallelResult(sepConfig: any): boolean
	return sepConfig == nil or sepConfig.ParallelAsyncUsePreviousResult ~= false
end


function MovementService:_GetAgentRadiusStuds(entity: number): number
	local params = self:_GetAgentParams(entity)
	local agentRadius = params.AgentRadius
	if type(agentRadius) == "number" and agentRadius > 0 then
		return agentRadius
	end
	return 2
end


function MovementService:_CreateFlowSeparationRuntime(sessionUserId: number?, currentTime: number?): TFlowSeparationRuntime
	return {
		SessionUserId = sessionUserId,
		CurrentTime = currentTime,
		CellWidthStuds = 0,
		EntityStateById = {},
		BucketsByCell = {},
		DirtyEntities = {},
		DirtyCells = {},
		TrackedFlowEntities = {},
		ActiveFlowEntities = {},
		ActiveSolveEntities = {},
	}
end


function MovementService:_GetOrCreateFlowSeparationRuntime(): TFlowSeparationRuntime
	local runtime = self._flowSeparationRuntime
	if runtime == nil then
		runtime = self:_CreateFlowSeparationRuntime(nil, nil)
		self._flowSeparationRuntime = runtime
	end
	return runtime
end


function MovementService:_AreCoveredCellsEqual(
	leftCells: { TFlowSeparationCoveredCell },
	rightCells: { TFlowSeparationCoveredCell }
): boolean
	if #leftCells ~= #rightCells then
		return false
	end

	for index = 1, #leftCells do
		if leftCells[index].Key ~= rightCells[index].Key then
			return false
		end
	end

	return true
end


function MovementService:_BuildFlowSeparationCoveredCells(
	flatPosition: Vector2,
	radius: number,
	cellWidthStuds: number
): { TFlowSeparationCoveredCell }
	local coveredCells: { TFlowSeparationCoveredCell } = {}
	MovementMath.ForEachCoveredSeparationCell(flatPosition, radius, cellWidthStuds, function(gx: number, gz: number)
		table.insert(coveredCells, {
			Key = MovementMath.PackedSeparationCellKey(gx, gz),
			Gx = gx,
			Gz = gz,
		})
	end)
	return coveredCells
end


function MovementService:_InsertEntityIntoFlowSeparationBuckets(
	entity: number,
	coveredCells: { TFlowSeparationCoveredCell }
)
	local runtime = self:_GetOrCreateFlowSeparationRuntime()
	for _, coveredCell in ipairs(coveredCells) do
		local bucket = runtime.BucketsByCell[coveredCell.Key]
		if bucket == nil then
			bucket = {}
			runtime.BucketsByCell[coveredCell.Key] = bucket
		end
		bucket[entity] = true
	end
	self:_IncrementFastFlowProfileCounter("BucketMembershipUpdates")
end


function MovementService:_RemoveEntityFromFlowSeparationBuckets(
	entity: number,
	coveredCells: { TFlowSeparationCoveredCell }
)
	local runtime = self:_GetOrCreateFlowSeparationRuntime()
	for _, coveredCell in ipairs(coveredCells) do
		local bucket = runtime.BucketsByCell[coveredCell.Key]
		if bucket ~= nil then
			bucket[entity] = nil
			if next(bucket) == nil then
				runtime.BucketsByCell[coveredCell.Key] = nil
			end
		end
	end
	self:_IncrementFastFlowProfileCounter("BucketMembershipUpdates")
end


function MovementService:_MarkFlowSeparationCellsDirty(
	coveredCells: { TFlowSeparationCoveredCell }
)
	local runtime = self:_GetOrCreateFlowSeparationRuntime()
	for _, coveredCell in ipairs(coveredCells) do
		for gx = coveredCell.Gx - 1, coveredCell.Gx + 1 do
			for gz = coveredCell.Gz - 1, coveredCell.Gz + 1 do
				local key = MovementMath.PackedSeparationCellKey(gx, gz)
				runtime.DirtyCells[key] = true
				local bucket = runtime.BucketsByCell[key]
				if bucket ~= nil then
					for entityId in bucket do
						runtime.DirtyEntities[entityId] = true
					end
				end
			end
		end
	end
end


function MovementService:_MarkFlowSeparationEntityDirty(entity: number)
	local runtime = self:_GetOrCreateFlowSeparationRuntime()
	runtime.DirtyEntities[entity] = true
end


function MovementService:_GetFlowSeparationDesiredCellWidth(): number
	local runtime = self:_GetOrCreateFlowSeparationRuntime()
	local maxRadius = 0
	for entityId in runtime.TrackedFlowEntities do
		local entityState = runtime.EntityStateById[entityId]
		if entityState ~= nil and entityState.Position ~= nil and entityState.Radius > maxRadius then
			maxRadius = entityState.Radius
		end
	end

	if maxRadius <= 0 then
		maxRadius = 2
	end

	return maxRadius * 2
end


function MovementService:_RefreshFlowSeparationCellWidth(): boolean
	local runtime = self:_GetOrCreateFlowSeparationRuntime()
	local desiredCellWidthStuds = self:_GetFlowSeparationDesiredCellWidth()
	if math.abs(runtime.CellWidthStuds - desiredCellWidthStuds) <= 1e-4 then
		return false
	end

	runtime.CellWidthStuds = desiredCellWidthStuds
	table.clear(runtime.BucketsByCell)
	table.clear(runtime.DirtyCells)
	table.clear(runtime.DirtyEntities)
	table.clear(runtime.ActiveSolveEntities)

	for entityId in runtime.TrackedFlowEntities do
		local entityState = runtime.EntityStateById[entityId]
		if entityState ~= nil then
			entityState.CoveredCells = {}
			entityState.Separation = Vector2.zero
			if entityState.FlatPosition ~= nil then
				entityState.CoveredCells = self:_BuildFlowSeparationCoveredCells(
					entityState.FlatPosition,
					entityState.Radius,
					runtime.CellWidthStuds
				)
				self:_InsertEntityIntoFlowSeparationBuckets(entityId, entityState.CoveredCells)
				self:_MarkFlowSeparationCellsDirty(entityState.CoveredCells)
			end
			runtime.DirtyEntities[entityId] = true
		end
	end

	return true
end


function MovementService:_ComputeFlowSeparationNearGoalScale(
	entityPosition: Vector3?,
	goalKey: string?,
	sepConfig: any
): number
	if entityPosition == nil or goalKey == nil then
		return 1
	end

	local nearGoalScale = self:_GetNearGoalSeparationScale(sepConfig)
	local nearGoalRadiusStuds = self:_GetNearGoalSeparationRadiusStuds(sepConfig)
	if nearGoalScale >= 1 or nearGoalRadiusStuds <= 0 then
		return 1
	end

	local sharedEntry = self:_GetSharedFlowfieldEntry(goalKey)
	if sharedEntry == nil then
		return 1
	end

	if MovementMath.XZDistance(entityPosition, sharedEntry.GoalWorldSample) <= nearGoalRadiusStuds then
		return nearGoalScale
	end

	return 1
end


function MovementService:_IsFlowEntityInsideNearGoalBand(
	entityPosition: Vector3?,
	goalKey: string?,
	sepConfig: any
): boolean
	return self:_ComputeFlowSeparationNearGoalScale(entityPosition, goalKey, sepConfig) < 1
end


function MovementService:_HasFlowSeparationMaterialMove(
	previousFlatPosition: Vector2?,
	nextFlatPosition: Vector2?,
	cellWidthStuds: number
): boolean
	if previousFlatPosition == nil or nextFlatPosition == nil then
		return previousFlatPosition ~= nextFlatPosition
	end

	local moveThreshold = math.max(0.25, cellWidthStuds * FLOW_SEPARATION_MATERIAL_MOVE_RATIO)
	return (previousFlatPosition - nextFlatPosition).Magnitude >= moveThreshold
end


function MovementService:_RemoveFlowSeparationEntity(entity: number)
	local runtime = self:_GetOrCreateFlowSeparationRuntime()
	local entityState = runtime.EntityStateById[entity]
	if entityState == nil then
		runtime.TrackedFlowEntities[entity] = nil
		runtime.ActiveFlowEntities[entity] = nil
		runtime.ActiveSolveEntities[entity] = nil
		runtime.DirtyEntities[entity] = nil
		return
	end

	local oldCoveredCells = entityState.CoveredCells
	if #oldCoveredCells > 0 then
		self:_RemoveEntityFromFlowSeparationBuckets(entity, oldCoveredCells)
		self:_MarkFlowSeparationCellsDirty(oldCoveredCells)
	end

	runtime.EntityStateById[entity] = nil
	runtime.TrackedFlowEntities[entity] = nil
	runtime.ActiveFlowEntities[entity] = nil
	runtime.ActiveSolveEntities[entity] = nil
	runtime.DirtyEntities[entity] = nil
	self:_RefreshFlowSeparationCellWidth()
end


function MovementService:_RefreshFlowSeparationEntitySpatialState(
	entity: number,
	entityPosition: Vector3?
): TFlowSeparationEntityState?
	local runtime = self:_GetOrCreateFlowSeparationRuntime()
	self:_IncrementFastFlowProfileCounter("SpatialRefreshCalls")
	local movementState = self._movementByEntity[entity]
	local tracked = (movementState ~= nil and movementState.Mode == "Flow")
		or self._flowSettleAnchorGoalKeyByEntity[entity] ~= nil
	if not tracked then
		self:_RemoveFlowSeparationEntity(entity)
		return nil
	end

	local resolvedPosition = if entityPosition ~= nil then entityPosition else self:_GetEntityPosition(entity)
	local flatPosition = if resolvedPosition ~= nil then MovementMath.FlatXZ(resolvedPosition) else nil
	local goalKey = self._flowGoalKeyByEntity[entity] or self._flowSettleAnchorGoalKeyByEntity[entity]
	local settled = self._flowSettledByEntity[entity] == true or self._flowSettleAnchorGoalKeyByEntity[entity] ~= nil
	local active = movementState ~= nil and movementState.Mode == "Flow" and resolvedPosition ~= nil and not settled
	local radius = self:_GetAgentRadiusStuds(entity)
	local sepConfig = CombatMovementConfig.FLOW_SOFT_SEPARATION

	local entityState = runtime.EntityStateById[entity]
	local previousCoveredCells = if entityState ~= nil then entityState.CoveredCells else {}
	local previousFlatPosition = if entityState ~= nil then entityState.FlatPosition else nil
	local previousGoalKey = if entityState ~= nil then entityState.GoalKey else nil
	local previousSettled = if entityState ~= nil then entityState.Settled else false
	local previousActive = if entityState ~= nil then entityState.Active else false
	local previousRadius = if entityState ~= nil then entityState.Radius else -1
	local previousLastSpatialRefreshFlatPosition = if entityState ~= nil then entityState.LastSpatialRefreshFlatPosition else nil
	local previousIsInsideNearGoalBand = if entityState ~= nil then entityState.IsInsideNearGoalBand else false
	local previousLastGoalKey = if entityState ~= nil then entityState.LastGoalKey else nil
	local previousLastDirtyMarkFlatPosition = if entityState ~= nil then entityState.LastDirtyMarkFlatPosition else nil

	if entityState == nil then
		entityState = {
			Position = nil,
			FlatPosition = nil,
			Radius = radius,
			GoalKey = nil,
			Settled = false,
			Active = false,
			CoveredCells = {},
			Separation = Vector2.zero,
			NearGoalScale = 1,
			LastSpatialRefreshFlatPosition = nil,
			IsInsideNearGoalBand = false,
			LastGoalKey = nil,
			LastDirtyMarkFlatPosition = nil,
		}
		runtime.EntityStateById[entity] = entityState
	end

	entityState.Position = resolvedPosition
	entityState.FlatPosition = flatPosition
	entityState.Radius = radius
	entityState.GoalKey = goalKey
	entityState.Settled = settled
	entityState.Active = active

	runtime.TrackedFlowEntities[entity] = true
	if active then
		runtime.ActiveFlowEntities[entity] = true
	else
		runtime.ActiveFlowEntities[entity] = nil
	end

	local didRebuildCellWidth = false
	if runtime.CellWidthStuds <= 0 or previousRadius ~= radius then
		didRebuildCellWidth = self:_RefreshFlowSeparationCellWidth()
	end

	local stateFlagsChanged = previousGoalKey ~= goalKey or previousSettled ~= settled or previousActive ~= active
	local materiallyMoved = not didRebuildCellWidth
		and self:_HasFlowSeparationMaterialMove(previousLastSpatialRefreshFlatPosition, flatPosition, runtime.CellWidthStuds)
	local shouldRecomputeNearGoalBand = goalKey ~= previousLastGoalKey
		or self:_HasFlowSeparationMaterialMove(previousFlatPosition, flatPosition, runtime.CellWidthStuds)
	if shouldRecomputeNearGoalBand then
		entityState.IsInsideNearGoalBand = self:_IsFlowEntityInsideNearGoalBand(resolvedPosition, goalKey, sepConfig)
		entityState.NearGoalScale = if entityState.IsInsideNearGoalBand
			then self:_GetNearGoalSeparationScale(sepConfig)
			else 1
		entityState.LastGoalKey = goalKey
		self:_IncrementFastFlowProfileCounter("NearGoalBandRecomputes")
	else
		entityState.IsInsideNearGoalBand = previousIsInsideNearGoalBand
		entityState.NearGoalScale = if previousIsInsideNearGoalBand then self:_GetNearGoalSeparationScale(sepConfig) else 1
		entityState.LastGoalKey = previousLastGoalKey
	end

	local nextCoveredCells = entityState.CoveredCells
	local shouldRecomputeCoveredCells = didRebuildCellWidth or stateFlagsChanged or materiallyMoved
	if shouldRecomputeCoveredCells and not didRebuildCellWidth then
		nextCoveredCells = if flatPosition ~= nil
			then self:_BuildFlowSeparationCoveredCells(flatPosition, radius, runtime.CellWidthStuds)
			else {}
		self:_IncrementFastFlowProfileCounter("CoveredCellRecomputes")
	end

	local coveredCellsChanged = not didRebuildCellWidth
		and not self:_AreCoveredCellsEqual(previousCoveredCells, nextCoveredCells)
	local dirtyMoveThreshold = self:_GetNeighborDirtyMoveThresholdStuds(sepConfig, runtime.CellWidthStuds)
	local dirtyMoved = if previousLastDirtyMarkFlatPosition ~= nil and flatPosition ~= nil
		then (previousLastDirtyMarkFlatPosition - flatPosition).Magnitude >= dirtyMoveThreshold
		else flatPosition ~= previousLastDirtyMarkFlatPosition

	if not didRebuildCellWidth and coveredCellsChanged then
		if #previousCoveredCells > 0 then
			self:_RemoveEntityFromFlowSeparationBuckets(entity, previousCoveredCells)
		end
		entityState.CoveredCells = nextCoveredCells
		if #nextCoveredCells > 0 then
			self:_InsertEntityIntoFlowSeparationBuckets(entity, nextCoveredCells)
		end
		self:_MarkFlowSeparationCellsDirty(previousCoveredCells)
		self:_MarkFlowSeparationCellsDirty(nextCoveredCells)
		entityState.LastDirtyMarkFlatPosition = flatPosition
		self:_IncrementFastFlowProfileCounter("DirtyMarksTriggered")
	elseif shouldRecomputeCoveredCells and not didRebuildCellWidth then
		entityState.CoveredCells = nextCoveredCells
		if stateFlagsChanged or dirtyMoved then
			self:_MarkFlowSeparationCellsDirty(nextCoveredCells)
			entityState.LastDirtyMarkFlatPosition = flatPosition
			self:_IncrementFastFlowProfileCounter("DirtyMarksTriggered")
		elseif materiallyMoved then
			self:_IncrementFastFlowProfileCounter("DirtyMarksSkipped")
		end
	end

	if shouldRecomputeCoveredCells then
		entityState.LastSpatialRefreshFlatPosition = flatPosition
	end

	if didRebuildCellWidth or coveredCellsChanged or stateFlagsChanged or dirtyMoved then
		entityState.Separation = Vector2.zero
		runtime.ActiveSolveEntities[entity] = nil
		self:_MarkFlowSeparationEntityDirty(entity)
	end

	return entityState
end


function MovementService:_CollectFlowSeparationAffectedEntities(): ({ [number]: boolean }, { number })
	local runtime = self:_GetOrCreateFlowSeparationRuntime()
	local affectedEntitySet: { [number]: boolean } = {}
	local affectedEntities: { number } = {}

	for entityId in runtime.DirtyEntities do
		affectedEntitySet[entityId] = true
	end

	for dirtyCellKey in runtime.DirtyCells do
		local bucket = runtime.BucketsByCell[dirtyCellKey]
		if bucket ~= nil then
			for entityId in bucket do
				affectedEntitySet[entityId] = true
			end
		end
	end

	for entityId in affectedEntitySet do
		table.insert(affectedEntities, entityId)
	end

	return affectedEntitySet, affectedEntities
end


function MovementService:_BuildFlowSeparationSolveSet(
	candidateEntities: { number },
	sepConfig: any
): ({ [number]: boolean }, { number })
	local runtime = self:_GetOrCreateFlowSeparationRuntime()
	local solveEntitySet: { [number]: boolean } = {}
	local solveEntities: { number } = {}
	if not self:_UseIsolationSkip(sepConfig) then
		for _, entityId in ipairs(candidateEntities) do
			local entityState = runtime.EntityStateById[entityId]
			if entityState ~= nil and entityState.Active and entityState.Position ~= nil then
				solveEntitySet[entityId] = true
				table.insert(solveEntities, entityId)
			end
		end
		return solveEntitySet, solveEntities
	end

	local isolationRadius = self:_GetIsolationSkipRadiusStuds(sepConfig)
	local cellWidthStuds = runtime.CellWidthStuds
	for _, entityId in ipairs(candidateEntities) do
		local entityState = runtime.EntityStateById[entityId]
		local hasNearbyNeighbor = false
		if entityState ~= nil and entityState.Active and entityState.Position ~= nil and entityState.FlatPosition ~= nil then
			local checkedNeighbors: { [number]: boolean } = {}
			MovementMath.ForEachCoveredSeparationCell(entityState.FlatPosition, isolationRadius, cellWidthStuds, function(gx: number, gz: number)
				if hasNearbyNeighbor then
					return
				end

				local bucket = runtime.BucketsByCell[MovementMath.PackedSeparationCellKey(gx, gz)]
				if bucket == nil then
					return
				end

				for otherEntityId in bucket do
					if otherEntityId ~= entityId and not checkedNeighbors[otherEntityId] then
						checkedNeighbors[otherEntityId] = true
						local otherState = runtime.EntityStateById[otherEntityId]
						if otherState ~= nil and otherState.Active and otherState.Position ~= nil then
							if MovementMath.XZDistance(entityState.Position, otherState.Position) <= isolationRadius then
								hasNearbyNeighbor = true
								return
							end
						end
					end
				end
			end)
		end

		if hasNearbyNeighbor then
			solveEntitySet[entityId] = true
			table.insert(solveEntities, entityId)
		end
	end

	return solveEntitySet, solveEntities
end


function MovementService:_GetOrCreateFlowSeparationParallelRunner(sepConfig: any)
	local runner = self._flowSeparationParallelRunner
	if runner ~= nil then
		return runner
	end

	runner = ParallelQuery.new({
		Name = "CombatFlowSeparation",
		ActorCount = self:_GetFlowSeparationParallelActorCount(sepConfig),
		Operations = {
			script.Parent.Parallel.FlowSeparationPairOperation,
			script.Parent.Parallel.FlowSeparationPairSnapshotOperation,
			script.Parent.Parallel.FlowVelocitySolveOperation,
		},
	})
	self._flowSeparationParallelRunner = runner
	return runner
end


function MovementService:_DestroyFlowSeparationParallelRunner()
	local runner = self._flowSeparationParallelRunner
	if runner == nil then
		return
	end

	runner:Destroy()
	self._flowSeparationParallelRunner = nil
end


function MovementService:_CreateFlowSeparationPairAsyncState(): TFlowSeparationPairAsyncState
	return {
		PendingRequestId = 0,
		LatestAppliedRequestId = 0,
		LatestCompletedResult = nil,
		InFlight = false,
		InFlightRequestId = nil,
		InFlightSessionUserId = nil,
		LastDispatchClock = 0,
	}
end


function MovementService:_GetOrCreateFlowSeparationPairAsyncState(): TFlowSeparationPairAsyncState
	local state = self._flowSeparationPairAsyncState
	if state == nil then
		state = self:_CreateFlowSeparationPairAsyncState()
		self._flowSeparationPairAsyncState = state
	end
	return state
end


function MovementService:_ClearFlowSeparationPairAsyncState()
	self._flowSeparationPairAsyncState = nil
end


function MovementService:_CreateFlowSeparationPairSnapshotBuildAsyncState(): TFlowSeparationPairSnapshotBuildAsyncState
	return {
		PendingRequestId = 0,
		LatestAppliedRequestId = 0,
		LatestCompletedResult = nil,
		InFlight = false,
		InFlightRequestId = nil,
		InFlightSessionUserId = nil,
		LastDispatchClock = 0,
	}
end


function MovementService:_GetOrCreateFlowSeparationPairSnapshotBuildAsyncState(): TFlowSeparationPairSnapshotBuildAsyncState
	local state = self._flowSeparationPairSnapshotBuildAsyncState
	if state == nil then
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
	if state == nil or not state.InFlight then
		return
	end

	local maxInFlightSeconds = self:_GetFlowSeparationParallelAsyncMaxInFlightSeconds(sepConfig)
	if os.clock() - state.LastDispatchClock <= maxInFlightSeconds then
		return
	end

	state.InFlight = false
	state.InFlightRequestId = nil
	state.InFlightSessionUserId = nil
	state.LatestCompletedResult = nil
	self:_IncrementFastFlowProfileCounter("ParallelFallbacks")
	self:_IncrementFastFlowProfileCounter("ParallelPairSnapshotAsyncDroppedResults")
end


function MovementService:_HasFlowSeparationPairSnapshotBuildAsyncRequestInFlight(sepConfig: any): boolean
	self:_ExpireFlowSeparationPairSnapshotBuildAsyncRequestIfNeeded(sepConfig)

	local state = self._flowSeparationPairSnapshotBuildAsyncState
	return state ~= nil and state.InFlight
end


function MovementService:_ExpireFlowSeparationPairAsyncRequestIfNeeded(sepConfig: any)
	local state = self._flowSeparationPairAsyncState
	if state == nil or not state.InFlight then
		return
	end

	local maxInFlightSeconds = self:_GetFlowSeparationParallelAsyncMaxInFlightSeconds(sepConfig)
	if os.clock() - state.LastDispatchClock <= maxInFlightSeconds then
		return
	end

	-- Pair and velocity operations share the same runner, so expiring a stale pair request
	-- must not tear down unrelated in-flight velocity work.
	state.InFlight = false
	state.InFlightRequestId = nil
	state.InFlightSessionUserId = nil
	state.LatestCompletedResult = nil
	self:_IncrementFastFlowProfileCounter("ParallelFallbacks")
	self:_IncrementFastFlowProfileCounter("ParallelAsyncDroppedResults")
end


function MovementService:_HasFlowSeparationPairAsyncRequestInFlight(sepConfig: any): boolean
	self:_ExpireFlowSeparationPairAsyncRequestIfNeeded(sepConfig)

	local state = self._flowSeparationPairAsyncState
	return state ~= nil and state.InFlight
end


function MovementService:_CreateFlowSeparationPairSnapshotBuildInput(
	candidateCellSet: { [number]: boolean },
	activeSolveEntitySet: { [number]: boolean },
	denseFallbackEntitySet: { [number]: boolean },
	sepConfig: any,
	kForce: number,
	minSeparationDistance: number
): TFlowSeparationPairSnapshotBuildInput
	local runtime = self:_GetOrCreateFlowSeparationRuntime()
	local maxPairsPerTask = self:_GetFlowSeparationParallelSnapshotBuildMaxPairsPerTask(sepConfig)
	self:_GetFlowSeparationParallelSnapshotBuildMaxEntitiesPerTask(sepConfig, maxPairsPerTask)

	local overflowMode = self:_GetFlowSeparationParallelSnapshotBuildOverflowMode(sepConfig)
	local input: TFlowSeparationPairSnapshotBuildInput = {
		CandidateCellKeys = {},
		CellEntityStarts = {},
		CellEntityCounts = {},
		EligibleEntityIds = {},
		TaskCellIndices = {},
		TaskOuterStartOffsets = {},
		TaskOuterEndOffsets = {},
		TaskEntityStartIndices = {},
		TaskEntityCounts = {},
		EntityPositionXById = {},
		EntityPositionYById = {},
		EntityRadiusById = {},
		KForce = kForce,
		MinSeparationDistance = minSeparationDistance,
	}

	local function addTask(cellIndex: number, cellStart: number, cellCount: number, outerStartOffset: number, outerEndOffset: number)
		local taskIndex = #input.TaskCellIndices + 1
		input.TaskCellIndices[taskIndex] = cellIndex
		input.TaskOuterStartOffsets[taskIndex] = outerStartOffset
		input.TaskOuterEndOffsets[taskIndex] = outerEndOffset
		input.TaskEntityStartIndices[taskIndex] = cellStart
		input.TaskEntityCounts[taskIndex] = cellCount
	end

	for candidateCellKey in candidateCellSet do
		local bucket = runtime.BucketsByCell[candidateCellKey]
		if bucket == nil then
			continue
		end

		local cellEligibleStart = #input.EligibleEntityIds + 1
		local cellEligibleCount = 0

		for entityId in bucket do
			if activeSolveEntitySet[entityId] and not denseFallbackEntitySet[entityId] then
				local entityState = runtime.EntityStateById[entityId]
				if entityState ~= nil and entityState.FlatPosition ~= nil then
					cellEligibleCount += 1
					input.EligibleEntityIds[cellEligibleStart + cellEligibleCount - 1] = entityId
					input.EntityPositionXById[entityId] = entityState.FlatPosition.X
					input.EntityPositionYById[entityId] = entityState.FlatPosition.Y
					input.EntityRadiusById[entityId] = entityState.Radius
				end
			end
		end

		if cellEligibleCount >= 2 then
			local cellIndex = #input.CandidateCellKeys + 1
			input.CandidateCellKeys[cellIndex] = candidateCellKey
			input.CellEntityStarts[cellIndex] = cellEligibleStart
			input.CellEntityCounts[cellIndex] = cellEligibleCount

			if overflowMode == "Local" and (cellEligibleCount * (cellEligibleCount - 1)) / 2 > maxPairsPerTask then
				self:_IncrementFastFlowProfileCounter("ParallelPairSnapshotOverflowLocalFallbacks")
			end

			local generatedTaskCount = 0
			local outerStartOffset = 0
			local lastOuterOffset = cellEligibleCount - 2

			while outerStartOffset <= lastOuterOffset do
				local outerEndOffset = outerStartOffset - 1
				local pairBudget = 0

				while outerEndOffset + 1 <= lastOuterOffset do
					local nextOuterOffset = outerEndOffset + 1
					local pairsForAnchor = cellEligibleCount - nextOuterOffset - 1
					assert(
						pairsForAnchor <= maxPairsPerTask,
						`Flow separation snapshot build anchor at offset {nextOuterOffset} exceeded worker pair budget`
					)
					if pairBudget > 0 and pairBudget + pairsForAnchor > maxPairsPerTask then
						break
					end

					pairBudget += pairsForAnchor
					outerEndOffset = nextOuterOffset
				end

				assert(outerEndOffset >= outerStartOffset, "Flow separation snapshot build planner failed to chunk work")

				addTask(cellIndex, cellEligibleStart, cellEligibleCount, outerStartOffset, outerEndOffset)
				generatedTaskCount += 1
				outerStartOffset = outerEndOffset + 1
			end

			if generatedTaskCount > 1 then
				self:_IncrementFastFlowProfileCounter("ParallelPairSnapshotChunkedCells")
			end
			self:_IncrementFastFlowProfileCounter("ParallelPairSnapshotTasksGenerated", generatedTaskCount)
		end
	end

	return input
end


function MovementService:_CreateFlowSeparationPairSnapshotBuildSharedMemory(
	input: TFlowSeparationPairSnapshotBuildInput
): SharedTable
	local memory = SharedTable.new()
	local cellEntityStarts = SharedTable.new()
	local cellEntityCounts = SharedTable.new()
	local eligibleEntityIds = SharedTable.new()
	local taskCellIndices = SharedTable.new()
	local taskOuterStartOffsets = SharedTable.new()
	local taskOuterEndOffsets = SharedTable.new()
	local taskEntityStartIndices = SharedTable.new()
	local taskEntityCounts = SharedTable.new()

	for index, value in ipairs(input.CellEntityStarts) do
		cellEntityStarts[index] = value
	end
	for index, value in ipairs(input.CellEntityCounts) do
		cellEntityCounts[index] = value
	end
	for index, value in ipairs(input.EligibleEntityIds) do
		eligibleEntityIds[index] = value
	end
	for index, value in ipairs(input.TaskCellIndices) do
		taskCellIndices[index] = value
	end
	for index, value in ipairs(input.TaskOuterStartOffsets) do
		taskOuterStartOffsets[index] = value
	end
	for index, value in ipairs(input.TaskOuterEndOffsets) do
		taskOuterEndOffsets[index] = value
	end
	for index, value in ipairs(input.TaskEntityStartIndices) do
		taskEntityStartIndices[index] = value
	end
	for index, value in ipairs(input.TaskEntityCounts) do
		taskEntityCounts[index] = value
	end

	memory.CellEntityStarts = cellEntityStarts
	memory.CellEntityCounts = cellEntityCounts
	memory.EligibleEntityIds = eligibleEntityIds
	memory.TaskCellIndices = taskCellIndices
	memory.TaskOuterStartOffsets = taskOuterStartOffsets
	memory.TaskOuterEndOffsets = taskOuterEndOffsets
	memory.TaskEntityStartIndices = taskEntityStartIndices
	memory.TaskEntityCounts = taskEntityCounts
	return memory
end


function MovementService:_BuildFlowSeparationPairSnapshotFromBuildInput(
	input: TFlowSeparationPairSnapshotBuildInput,
	rows: { [number]: { [string]: any } }?
): (TFlowSeparationPairSnapshot?, boolean)
	local buildStartedAt = os.clock()
	local snapshot: TFlowSeparationPairSnapshot = {
		EntityIds = {},
		EntityIndexById = {},
		PositionX = {},
		PositionY = {},
		Radius = {},
		PairA = {},
		PairB = {},
		KForce = input.KForce,
		MinSeparationDistance = input.MinSeparationDistance,
	}
	local processedPairs: { [string]: boolean } = {}

	local function getEntityIndex(entityId: number): number?
		local entityIndex = snapshot.EntityIndexById[entityId]
		if entityIndex ~= nil then
			return entityIndex
		end

		local positionX = input.EntityPositionXById[entityId]
		local positionY = input.EntityPositionYById[entityId]
		local radius = input.EntityRadiusById[entityId]
		if type(positionX) ~= "number" or type(positionY) ~= "number" or type(radius) ~= "number" then
			return nil
		end

		entityIndex = #snapshot.EntityIds + 1
		snapshot.EntityIds[entityIndex] = entityId
		snapshot.EntityIndexById[entityId] = entityIndex
		snapshot.PositionX[entityIndex] = positionX
		snapshot.PositionY[entityIndex] = positionY
		snapshot.Radius[entityIndex] = radius
		return entityIndex
	end

	local function appendPair(entityA: number, entityB: number)
		local pairKey = string.format("%d:%d", math.min(entityA, entityB), math.max(entityA, entityB))
		if processedPairs[pairKey] then
			return
		end

		local entityIndexA = getEntityIndex(entityA)
		local entityIndexB = getEntityIndex(entityB)
		if entityIndexA == nil or entityIndexB == nil then
			return
		end

		processedPairs[pairKey] = true
		table.insert(snapshot.PairA, entityIndexA)
		table.insert(snapshot.PairB, entityIndexB)
	end

	if rows == nil then
		return nil, false
	end

	for _, row in ipairs(rows) do
		if row.Overflow == true then
			return nil, true
		end

		local pairCount = row.PairCount
		if type(pairCount) ~= "number" then
			continue
		end

		for pairIndex = 1, pairCount do
			local entityA, entityB = FlowSeparationPairSnapshotCodec.ReadPair(row, pairIndex)
			if entityA ~= nil and entityB ~= nil and entityA ~= 0 and entityB ~= 0 then
				appendPair(entityA, entityB)
			end
		end
	end

	self:_IncrementFastFlowProfileCounter("ParallelPairSnapshotBuilds")
	self:_IncrementFastFlowProfileCounter("ParallelPairSnapshotEntities", #snapshot.EntityIds)
	self:_IncrementFastFlowProfileCounter("ParallelPairSnapshotPairs", #snapshot.PairA)
	self:_IncrementFastFlowProfileCounter("ParallelPairSnapshotBuildMilliseconds", (os.clock() - buildStartedAt) * 1000)
	return snapshot, false
end


function MovementService:_CreateFlowSeparationSharedMemory(snapshot: TFlowSeparationPairSnapshot): SharedTable
	local memory = SharedTable.new()
	local positionX = SharedTable.new()
	local positionY = SharedTable.new()
	local radius = SharedTable.new()
	local pairA = SharedTable.new()
	local pairB = SharedTable.new()

	for index, value in ipairs(snapshot.PositionX) do
		positionX[index] = value
	end
	for index, value in ipairs(snapshot.PositionY) do
		positionY[index] = value
	end
	for index, value in ipairs(snapshot.Radius) do
		radius[index] = value
	end
	for index, value in ipairs(snapshot.PairA) do
		pairA[index] = value
	end
	for index, value in ipairs(snapshot.PairB) do
		pairB[index] = value
	end

	memory.PositionX = positionX
	memory.PositionY = positionY
	memory.Radius = radius
	memory.PairA = pairA
	memory.PairB = pairB
	memory.KForce = snapshot.KForce
	memory.MinSeparationDistance = snapshot.MinSeparationDistance

	return memory
end


function MovementService:_MarkFlowSeparationBuildInputDirty(input: TFlowSeparationPairSnapshotBuildInput)
	local runtime = self:_GetOrCreateFlowSeparationRuntime()

	for _, cellKey in ipairs(input.CandidateCellKeys) do
		runtime.DirtyCells[cellKey] = true
	end

	for _, entityId in ipairs(input.EligibleEntityIds) do
		runtime.DirtyEntities[entityId] = true
	end
end


function MovementService:_MarkFlowSeparationSnapshotDirty(snapshot: TFlowSeparationPairSnapshot)
	local runtime = self:_GetOrCreateFlowSeparationRuntime()

	for _, entityId in ipairs(snapshot.EntityIds) do
		runtime.DirtyEntities[entityId] = true
	end
end


function MovementService:_CompleteFlowSeparationPairSnapshotBuildAsyncRequest(
	result: TFlowSeparationPairSnapshotBuildAsyncResult
)
	local state = self._flowSeparationPairSnapshotBuildAsyncState
	if state == nil then
		return
	end

	if state.InFlightRequestId ~= result.RequestId then
		self:_IncrementFastFlowProfileCounter("ParallelPairSnapshotAsyncStaleResults")
		return
	end

	if state.LatestCompletedResult ~= nil then
		self:_IncrementFastFlowProfileCounter("ParallelPairSnapshotAsyncDroppedResults")
	end

	state.InFlight = false
	state.InFlightRequestId = nil
	state.InFlightSessionUserId = nil
	state.LatestCompletedResult = result
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
	local requestId = state.PendingRequestId + 1
	state.PendingRequestId = requestId
	state.InFlight = true
	state.InFlightRequestId = requestId
	state.InFlightSessionUserId = sessionUserId
	state.LastDispatchClock = os.clock()

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

	if not ok or promise == nil then
		state.InFlight = false
		state.InFlightRequestId = nil
		state.InFlightSessionUserId = nil
		self:_IncrementFastFlowProfileCounter("ParallelFallbacks")
		self:_IncrementFastFlowProfileCounter("ParallelPairSnapshotAsyncErrorFallbacks")
		return "Failed"
	end

	promise:andThen(function(resultRows)
		self:_CompleteFlowSeparationPairSnapshotBuildAsyncRequest({
			RequestId = requestId,
			SessionUserId = sessionUserId,
			Input = input,
			Rows = resultRows :: any,
			Err = nil,
		})
	end):catch(function(resultErr)
		self:_CompleteFlowSeparationPairSnapshotBuildAsyncRequest({
			RequestId = requestId,
			SessionUserId = sessionUserId,
			Input = input,
			Rows = nil,
			Err = resultErr,
		})
	end)

	self:_IncrementFastFlowProfileCounter("ParallelPairSnapshotAsyncDispatches")
	return "Dispatched"
end


function MovementService:_ApplyCompletedFlowSeparationPairSnapshotBuildAsyncResult(
	sepConfig: any
): TFlowSeparationPairSnapshot?
	local state = self._flowSeparationPairSnapshotBuildAsyncState
	if state == nil or state.LatestCompletedResult == nil then
		return nil
	end

	local result = state.LatestCompletedResult
	state.LatestCompletedResult = nil
	self:_IncrementFastFlowProfileCounter("ParallelPairSnapshotAsyncCompleted")

	local runtime = self:_GetOrCreateFlowSeparationRuntime()
	local isStaleResult = result.RequestId <= state.LatestAppliedRequestId
		or result.SessionUserId ~= runtime.SessionUserId
	if isStaleResult then
		self:_IncrementFastFlowProfileCounter("ParallelPairSnapshotAsyncStaleResults")
		return nil
	end

	state.LatestAppliedRequestId = result.RequestId

	if result.Err ~= nil or result.Rows == nil then
		self:_IncrementFastFlowProfileCounter("ParallelFallbacks")
		self:_IncrementFastFlowProfileCounter("ParallelPairSnapshotAsyncErrorFallbacks")
		self:_MarkFlowSeparationBuildInputDirty(result.Input)
		return nil
	end

	local snapshot, didOverflow = self:_BuildFlowSeparationPairSnapshotFromBuildInput(result.Input, result.Rows :: any)
	if didOverflow then
		self:_IncrementFastFlowProfileCounter("ParallelFallbacks")
		self:_IncrementFastFlowProfileCounter("ParallelPairSnapshotAsyncErrorFallbacks")
		self:_MarkFlowSeparationBuildInputDirty(result.Input)
		return nil
	end

	if snapshot ~= nil then
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
	if entityId == nil then
		return
	end

	local runtime = self:_GetOrCreateFlowSeparationRuntime()
	local entityState = runtime.EntityStateById[entityId]
	if entityState == nil then
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
	-- Treat worker output as untrusted: ignore malformed or stale row references.
	for _, row in ipairs(rows) do
		local entityIndexA = row.EntityIndexA
		local entityIndexB = row.EntityIndexB
		if type(entityIndexA) ~= "number" or type(entityIndexB) ~= "number" then
			continue
		end
		if snapshot.EntityIds[entityIndexA] == nil or snapshot.EntityIds[entityIndexB] == nil then
			continue
		end

		local deltaAX = row.DeltaAX
		local deltaAY = row.DeltaAY
		local deltaBX = row.DeltaBX
		local deltaBY = row.DeltaBY
		if type(deltaAX) ~= "number" or type(deltaAY) ~= "number" or type(deltaBX) ~= "number" or type(deltaBY) ~= "number" then
			continue
		end

		self:_ApplyFlowSeparationPairDelta(snapshot, entityIndexA, Vector2.new(deltaAX, deltaAY), scaleDeltas)
		self:_ApplyFlowSeparationPairDelta(snapshot, entityIndexB, Vector2.new(deltaBX, deltaBY), scaleDeltas)
		if deltaAX ~= 0 or deltaAY ~= 0 or deltaBX ~= 0 or deltaBY ~= 0 then
			self:_IncrementFastFlowProfileCounter("ParallelPairRowsApplied")
		end
	end
end


function MovementService:_ApplyCompletedFlowSeparationPairAsyncResult(sepConfig: any)
	local state = self._flowSeparationPairAsyncState
	if state == nil or state.LatestCompletedResult == nil then
		return
	end

	local result = state.LatestCompletedResult
	state.LatestCompletedResult = nil
	self:_IncrementFastFlowProfileCounter("ParallelAsyncCompleted")

	local runtime = self:_GetOrCreateFlowSeparationRuntime()
	local isStaleResult = result.RequestId <= state.LatestAppliedRequestId
		or result.SessionUserId ~= runtime.SessionUserId
	if isStaleResult then
		self:_IncrementFastFlowProfileCounter("ParallelAsyncStaleResults")
		return
	end

	state.LatestAppliedRequestId = result.RequestId
	if result.Err ~= nil or result.Rows == nil then
		self:_IncrementFastFlowProfileCounter("ParallelFallbacks")
		self:_IncrementFastFlowProfileCounter("ParallelPairAsyncErrorFallbacks")
		self:_MarkFlowSeparationSnapshotDirty(result.Snapshot)
		return
	end

	self:_ApplyFlowSeparationPairRows(result.Snapshot, result.Rows, true)
	self:_IncrementFastFlowProfileCounter("ParallelAsyncApplied")
end


function MovementService:_CompleteFlowSeparationPairAsyncRequest(result: TFlowSeparationPairAsyncResult)
	local state = self._flowSeparationPairAsyncState
	if state == nil then
		return
	end

	if state.InFlightRequestId ~= result.RequestId then
		self:_IncrementFastFlowProfileCounter("ParallelAsyncStaleResults")
		return
	end

	if state.LatestCompletedResult ~= nil then
		self:_IncrementFastFlowProfileCounter("ParallelAsyncDroppedResults")
	end

	state.InFlight = false
	state.InFlightRequestId = nil
	state.InFlightSessionUserId = nil
	state.LatestCompletedResult = result
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

	if self:_HasFlowSeparationPairAsyncRequestInFlight(sepConfig) then
		return "InFlight"
	end

	local runtime = self:_GetOrCreateFlowSeparationRuntime()
	local sessionUserId = runtime.SessionUserId
	local state = self:_GetOrCreateFlowSeparationPairAsyncState()
	local requestId = state.PendingRequestId + 1
	state.PendingRequestId = requestId
	state.InFlight = true
	state.InFlightRequestId = requestId
	state.InFlightSessionUserId = sessionUserId
	state.LastDispatchClock = os.clock()

	local promise: typeof(Promise.new(function() end))? = nil
	local ok = pcall(function()
		local runner = self:_GetOrCreateFlowSeparationParallelRunner(sepConfig)
		local batchSize = self:_GetFlowSeparationParallelBatchSize(sepConfig)
		runner:SetLocalMemory(FLOW_SEPARATION_PAIR_OPERATION_NAME, self:_CreateFlowSeparationSharedMemory(snapshot))
		promise = runner:RunAsync(FLOW_SEPARATION_PAIR_OPERATION_NAME, {
			WorkCount = pairCount,
			BatchSize = batchSize,
			TimeoutSeconds = self:_GetFlowSeparationParallelTimeoutSeconds(sepConfig),
		})
	end)

	if not ok or promise == nil then
		state.InFlight = false
		state.InFlightRequestId = nil
		state.InFlightSessionUserId = nil
		self:_IncrementFastFlowProfileCounter("ParallelFallbacks")
		self:_IncrementFastFlowProfileCounter("ParallelPairFailedFallbacks")
		return "Failed"
	end

	promise:andThen(function(resultRows)
		self:_CompleteFlowSeparationPairAsyncRequest({
			RequestId = requestId,
			SessionUserId = sessionUserId,
			Snapshot = snapshot,
			Rows = resultRows :: any,
			Err = nil,
		})
	end):catch(function(resultErr)
		self:_CompleteFlowSeparationPairAsyncRequest({
			RequestId = requestId,
			SessionUserId = sessionUserId,
			Snapshot = snapshot,
			Rows = nil,
			Err = resultErr,
		})
	end)

	-- The pairwise stage is the canonical async path: snapshot -> dispatch -> apply/fallback.
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


function MovementService:_RecomputeDirtyFlowSeparation(sepConfig: any)
	local runtime = self:_GetOrCreateFlowSeparationRuntime()
	self:_ApplyCompletedFlowSeparationPairAsyncResult(sepConfig)
	local completedPairSnapshot = self:_ApplyCompletedFlowSeparationPairSnapshotBuildAsyncResult(sepConfig)
	if completedPairSnapshot ~= nil then
		self:_ResolveFlowSeparationPairSnapshot(completedPairSnapshot, sepConfig, true)
	end

	if next(runtime.DirtyEntities) == nil and next(runtime.DirtyCells) == nil then
		self:_SetFastFlowProfileCounter("TrackedFlowEntities", self:_CountTableEntries(runtime.TrackedFlowEntities))
		self:_SetFastFlowProfileCounter("ActiveSeparationEntities", self:_CountTableEntries(runtime.ActiveSolveEntities))
		return
	end

	if self:_IsFlowSeparationParallelSnapshotBuildEnabled(sepConfig)
		and self:_ShouldUsePreviousFlowSeparationParallelResult(sepConfig)
		and self:_HasFlowSeparationPairSnapshotBuildAsyncRequestInFlight(sepConfig)
	then
		self:_IncrementFastFlowProfileCounter("ParallelPairSnapshotAsyncInFlightSkips")
		self:_SetFastFlowProfileCounter("TrackedFlowEntities", self:_CountTableEntries(runtime.TrackedFlowEntities))
		self:_SetFastFlowProfileCounter("ActiveSeparationEntities", self:_CountTableEntries(runtime.ActiveSolveEntities))
		return
	end

	if self:_IsFlowSeparationParallelAsyncEnabled(sepConfig)
		and self:_ShouldUsePreviousFlowSeparationParallelResult(sepConfig)
		and self:_HasFlowSeparationPairAsyncRequestInFlight(sepConfig)
	then
		self:_IncrementFastFlowProfileCounter("ParallelAsyncInFlightSkips")
		self:_SetFastFlowProfileCounter("TrackedFlowEntities", self:_CountTableEntries(runtime.TrackedFlowEntities))
		self:_SetFastFlowProfileCounter("ActiveSeparationEntities", self:_CountTableEntries(runtime.ActiveSolveEntities))
		return
	end

	local _affectedEntitySet, affectedEntities = self:_CollectFlowSeparationAffectedEntities()
	local candidateCellSet: { [number]: boolean } = {}
	local recomputedEntitySet: { [number]: boolean } = {}
	local recomputedEntities: { number } = {}

	self:_IncrementFastFlowProfileCounter("DirtyEntitiesProcessed", #affectedEntities)
	self:_IncrementFastFlowProfileCounter("DirtyCellsProcessed", self:_CountTableEntries(runtime.DirtyCells))

	for _, entityId in ipairs(affectedEntities) do
		local entityState = runtime.EntityStateById[entityId]
		if entityState ~= nil then
			for _, coveredCell in ipairs(entityState.CoveredCells) do
				candidateCellSet[coveredCell.Key] = true
			end
		end
	end

	for candidateCellKey in candidateCellSet do
		local bucket = runtime.BucketsByCell[candidateCellKey]
		if bucket ~= nil then
			for entityId in bucket do
				if not recomputedEntitySet[entityId] then
					recomputedEntitySet[entityId] = true
					table.insert(recomputedEntities, entityId)
				end
			end
		end
	end

	for _, entityId in ipairs(recomputedEntities) do
		local entityState = runtime.EntityStateById[entityId]
		if entityState ~= nil then
			entityState.Separation = Vector2.zero
		end
		runtime.ActiveSolveEntities[entityId] = nil
	end

	local activeSolveEntitySet, activeSolveEntities = self:_BuildFlowSeparationSolveSet(recomputedEntities, sepConfig)
	for _, entityId in ipairs(activeSolveEntities) do
		runtime.ActiveSolveEntities[entityId] = true
	end

	local kForce = if type(sepConfig.KForce) == "number" then sepConfig.KForce else 80
	local minSeparationDistance = if type(sepConfig.MinSeparationDistance) == "number" then sepConfig.MinSeparationDistance else 1e-4
	local denseFallbackEntitySet: { [number]: boolean } = {}

	if self:_UseDenseCellFallback(sepConfig) then
		local denseCellThreshold = self:_GetDenseCellOccupancyThreshold(sepConfig)
		for candidateCellKey in candidateCellSet do
			local bucket = runtime.BucketsByCell[candidateCellKey]
			if bucket ~= nil then
				local activeCellEntities: { number } = {}
				for entityId in bucket do
					if activeSolveEntitySet[entityId] then
						table.insert(activeCellEntities, entityId)
					end
				end

				if #activeCellEntities > denseCellThreshold then
					self:_IncrementFastFlowProfileCounter("DenseCellsEncountered")
					self:_IncrementFastFlowProfileCounter("DenseCellFallbackActivations")

					local center = Vector2.zero
					for _, entityId in ipairs(activeCellEntities) do
						local entityState = runtime.EntityStateById[entityId]
						if entityState ~= nil and entityState.FlatPosition ~= nil then
							center += entityState.FlatPosition
							denseFallbackEntitySet[entityId] = true
						end
					end

					center = center / #activeCellEntities
					for _, entityId in ipairs(activeCellEntities) do
						local entityState = runtime.EntityStateById[entityId]
						if entityState ~= nil and entityState.FlatPosition ~= nil then
							local displacement = entityState.FlatPosition - center
							local distance = displacement.Magnitude
							if distance > minSeparationDistance then
								local crowdPressure = math.max(0, entityState.Radius * #activeCellEntities - distance)
								if crowdPressure > 0 then
									entityState.Separation += kForce * (displacement / distance) * crowdPressure
								end
							end
						end
					end
				end
			end
		end
	end

	if self:_IsFlowSeparationParallelSnapshotBuildEnabled(sepConfig) then
		local buildInput = self:_CreateFlowSeparationPairSnapshotBuildInput(
			candidateCellSet,
			activeSolveEntitySet,
			denseFallbackEntitySet,
			sepConfig,
			kForce,
			minSeparationDistance
		)
		if #buildInput.TaskCellIndices == 0 then
			table.clear(runtime.DirtyEntities)
			table.clear(runtime.DirtyCells)
			self:_SetFastFlowProfileCounter("TrackedFlowEntities", self:_CountTableEntries(runtime.TrackedFlowEntities))
			self:_SetFastFlowProfileCounter("ActiveSeparationEntities", self:_CountTableEntries(runtime.ActiveSolveEntities))
			return
		end

		local snapshotBuildStatus = self:_DispatchFlowSeparationPairSnapshotBuildAsync(buildInput, sepConfig)
		if snapshotBuildStatus == "Dispatched" or snapshotBuildStatus == "InFlight" then
			table.clear(runtime.DirtyEntities)
			table.clear(runtime.DirtyCells)
			self:_SetFastFlowProfileCounter("TrackedFlowEntities", self:_CountTableEntries(runtime.TrackedFlowEntities))
			self:_SetFastFlowProfileCounter("ActiveSeparationEntities", self:_CountTableEntries(runtime.ActiveSolveEntities))
			return
		end
		if snapshotBuildStatus == "Failed" then
			self:_SetFastFlowProfileCounter("TrackedFlowEntities", self:_CountTableEntries(runtime.TrackedFlowEntities))
			self:_SetFastFlowProfileCounter("ActiveSeparationEntities", self:_CountTableEntries(runtime.ActiveSolveEntities))
			return
		end
	end

	self:_SetFastFlowProfileCounter("TrackedFlowEntities", self:_CountTableEntries(runtime.TrackedFlowEntities))
	self:_SetFastFlowProfileCounter("ActiveSeparationEntities", self:_CountTableEntries(runtime.ActiveSolveEntities))
end


function MovementService:_GetFlowSoftSeparationXZ(entity: number, sepConfig: any): Vector2
	self:_RecomputeDirtyFlowSeparation(sepConfig)
	local runtime = self:_GetOrCreateFlowSeparationRuntime()
	local entityState = runtime.EntityStateById[entity]
	return if entityState ~= nil then entityState.Separation else Vector2.zero
end

end
