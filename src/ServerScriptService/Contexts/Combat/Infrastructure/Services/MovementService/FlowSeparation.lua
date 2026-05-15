--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CombatMovementConfig = require(ReplicatedStorage.Contexts.Combat.Config.CombatMovementConfig)
local BoidsConfig = require(ReplicatedStorage.Contexts.Combat.Config.BoidsConfig)
local MovementTypes = require(script.Parent.Types)
local MovementMath = require(script.Parent.MovementMath)

type TFlowSeparationCoveredCell = MovementTypes.TFlowSeparationCoveredCell
type TFlowSeparationEntityState = MovementTypes.TFlowSeparationEntityState
type TFlowSeparationRuntime = MovementTypes.TFlowSeparationRuntime

local FLOW_SEPARATION_MATERIAL_MOVE_RATIO = 0.25

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
	return sepConfig ~= nil and sepConfig.DenseCellFallbackEnabled == true
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


function MovementService:_RecomputeDirtyFlowSeparation(sepConfig: any)
	local runtime = self:_GetOrCreateFlowSeparationRuntime()
	if next(runtime.DirtyEntities) == nil and next(runtime.DirtyCells) == nil then
		self:_SetFastFlowProfileCounter("TrackedFlowEntities", self:_CountTableEntries(runtime.TrackedFlowEntities))
		self:_SetFastFlowProfileCounter("ActiveSeparationEntities", self:_CountTableEntries(runtime.ActiveSolveEntities))
		return
	end

	local affectedEntitySet, affectedEntities = self:_CollectFlowSeparationAffectedEntities()
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

	local processedPairs: { [string]: boolean } = {}
	for candidateCellKey in candidateCellSet do
		local bucket = runtime.BucketsByCell[candidateCellKey]
		if bucket ~= nil then
			local cellEntities: { number } = {}
			for entityId in bucket do
				table.insert(cellEntities, entityId)
			end

			for index = 1, #cellEntities do
				local entityA = cellEntities[index]
				local entityStateA = runtime.EntityStateById[entityA]
				if entityStateA ~= nil and activeSolveEntitySet[entityA] and not denseFallbackEntitySet[entityA] then
					for otherIndex = index + 1, #cellEntities do
						local entityB = cellEntities[otherIndex]
						if activeSolveEntitySet[entityB] and not denseFallbackEntitySet[entityB] then
							local pairKey = string.format("%d:%d", math.min(entityA, entityB), math.max(entityA, entityB))
							if not processedPairs[pairKey] then
								processedPairs[pairKey] = true
								local entityStateB = runtime.EntityStateById[entityB]
								if entityStateB ~= nil and entityStateA.FlatPosition ~= nil and entityStateB.FlatPosition ~= nil then
									local displacement = entityStateA.FlatPosition - entityStateB.FlatPosition
									local distance = displacement.Magnitude
									local penetration = entityStateA.Radius + entityStateB.Radius - distance
									if penetration > 0 and distance > minSeparationDistance then
										local separationDelta = kForce * (displacement / distance) * penetration * penetration
										entityStateA.Separation += separationDelta
										entityStateB.Separation -= separationDelta
										self:_IncrementFastFlowProfileCounter("LocalPairSolves")
									end
								end
							end
						end
					end
				end
			end
		end
	end

	for _, entityId in ipairs(recomputedEntities) do
		local entityState = runtime.EntityStateById[entityId]
		if entityState ~= nil and entityState.NearGoalScale < 1 then
			entityState.Separation *= entityState.NearGoalScale
		end
	end

	table.clear(runtime.DirtyEntities)
	table.clear(runtime.DirtyCells)
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
