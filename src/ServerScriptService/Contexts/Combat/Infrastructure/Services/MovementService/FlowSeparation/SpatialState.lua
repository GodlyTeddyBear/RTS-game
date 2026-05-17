--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CombatMovementConfig = require(ReplicatedStorage.Contexts.Combat.Config.CombatMovementConfig)
local MovementTypes = require(script.Parent.Parent.Types)
local MovementMath = require(script.Parent.Parent.MovementMath)

type TFlowSeparationEntityState = MovementTypes.TFlowSeparationEntityState

local FLOW_SEPARATION_MATERIAL_MOVE_RATIO = 0.25

return function(MovementService: any)
	function MovementService:_ComputeFlowSeparationNearGoalScale(
		entityPosition: Vector3?,
		goalKey: string?,
		sepConfig: any
	): number
		if not entityPosition or not goalKey then
			return 1
		end

		local nearGoalScale = self:_GetNearGoalSeparationScale(sepConfig)
		local nearGoalRadiusStuds = self:_GetNearGoalSeparationRadiusStuds(sepConfig)
		if nearGoalScale >= 1 or nearGoalRadiusStuds <= 0 then
			return 1
		end

		local sharedEntry = self:_GetSharedFlowfieldEntry(goalKey)
		if not sharedEntry then
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
		if not previousFlatPosition or not nextFlatPosition then
			return previousFlatPosition ~= nextFlatPosition
		end

		local moveThreshold = math.max(0.25, cellWidthStuds * FLOW_SEPARATION_MATERIAL_MOVE_RATIO)
		return (previousFlatPosition - nextFlatPosition).Magnitude >= moveThreshold
	end

	function MovementService:_RefreshFlowSeparationEntitySpatialState(
		entity: number,
		entityPosition: Vector3?
	): TFlowSeparationEntityState?
		local runtime = self:_GetOrCreateFlowSeparationRuntime()
		self:_IncrementFastFlowProfileCounter("SpatialRefreshCalls")
		local movementState = self._movementByEntity[entity]
		local tracked = (movementState and movementState.Mode == "Flow")
			or self._flowSettleAnchorGoalKeyByEntity[entity] ~= nil
		if not tracked then
			self:_RemoveFlowSeparationEntity(entity)
			return
		end

		local resolvedPosition = entityPosition or self:_GetEntityPosition(entity)
		local flatPosition = resolvedPosition and MovementMath.FlatXZ(resolvedPosition)
		local goalKey = self._flowGoalKeyByEntity[entity] or self._flowSettleAnchorGoalKeyByEntity[entity]
		local settled = self._flowSettledByEntity[entity] == true or self._flowSettleAnchorGoalKeyByEntity[entity] ~= nil
		local active = movementState and movementState.Mode == "Flow" and resolvedPosition and not settled
		local radius = self:_GetAgentRadiusStuds(entity)
		local sepConfig = CombatMovementConfig.FLOW_SOFT_SEPARATION

		local entityState = runtime.EntityStateById[entity]
		local previousCoveredCells = entityState and entityState.CoveredCells or {}
		local previousFlatPosition = entityState and entityState.FlatPosition
		local previousGoalKey = entityState and entityState.GoalKey
		local previousSettled = entityState and entityState.Settled or false
		local previousActive = entityState and entityState.Active or false
		local previousRadius = entityState and entityState.Radius or -1
		local previousLastSpatialRefreshFlatPosition = entityState and entityState.LastSpatialRefreshFlatPosition
		local previousIsInsideNearGoalBand = entityState and entityState.IsInsideNearGoalBand or false
		local previousLastGoalKey = entityState and entityState.LastGoalKey
		local previousLastDirtyMarkFlatPosition = entityState and entityState.LastDirtyMarkFlatPosition

		if not entityState then
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
			entityState.NearGoalScale = (entityState.IsInsideNearGoalBand and self:_GetNearGoalSeparationScale(sepConfig)) or 1
			entityState.LastGoalKey = goalKey
			self:_IncrementFastFlowProfileCounter("NearGoalBandRecomputes")
		else
			entityState.IsInsideNearGoalBand = previousIsInsideNearGoalBand
			entityState.NearGoalScale = (previousIsInsideNearGoalBand and self:_GetNearGoalSeparationScale(sepConfig)) or 1
			entityState.LastGoalKey = previousLastGoalKey
		end

		local nextCoveredCells = entityState.CoveredCells
		local shouldRecomputeCoveredCells = didRebuildCellWidth or stateFlagsChanged or materiallyMoved
		if shouldRecomputeCoveredCells and not didRebuildCellWidth then
			nextCoveredCells = (flatPosition and self:_BuildFlowSeparationCoveredCells(flatPosition, radius, runtime.CellWidthStuds))
				or {}
			self:_IncrementFastFlowProfileCounter("CoveredCellRecomputes")
		end

		local coveredCellsChanged = not didRebuildCellWidth
			and not self:_AreCoveredCellsEqual(previousCoveredCells, nextCoveredCells)
		local dirtyMoveThreshold = self:_GetNeighborDirtyMoveThresholdStuds(sepConfig, runtime.CellWidthStuds)
		local dirtyMoved = ((previousLastDirtyMarkFlatPosition and flatPosition)
				and ((previousLastDirtyMarkFlatPosition - flatPosition).Magnitude >= dirtyMoveThreshold))
			or (flatPosition ~= previousLastDirtyMarkFlatPosition)

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
			if bucket then
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
				if entityState and entityState.Active and entityState.Position then
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
			if entityState and entityState.Active and entityState.Position and entityState.FlatPosition then
				local checkedNeighbors: { [number]: boolean } = {}
				MovementMath.ForEachCoveredSeparationCell(entityState.FlatPosition, isolationRadius, cellWidthStuds, function(gx: number, gz: number)
					if hasNearbyNeighbor then
						return
					end

					local bucket = runtime.BucketsByCell[MovementMath.PackedSeparationCellKey(gx, gz)]
					if not bucket then
						return
					end

					for otherEntityId in bucket do
						if otherEntityId ~= entityId and not checkedNeighbors[otherEntityId] then
							checkedNeighbors[otherEntityId] = true
							local otherState = runtime.EntityStateById[otherEntityId]
							if otherState and otherState.Active and otherState.Position then
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
end
