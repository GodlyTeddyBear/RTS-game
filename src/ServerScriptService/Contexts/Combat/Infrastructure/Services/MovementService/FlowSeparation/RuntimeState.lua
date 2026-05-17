--!strict

local MovementTypes = require(script.Parent.Parent.Types)
local MovementMath = require(script.Parent.Parent.MovementMath)

type TFlowSeparationCoveredCell = MovementTypes.TFlowSeparationCoveredCell
type TFlowSeparationRuntime = MovementTypes.TFlowSeparationRuntime

return function(MovementService: any)
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
		if not runtime then
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
			if not bucket then
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
			if bucket then
				bucket[entity] = nil
				if not next(bucket) then
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
					if bucket then
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
			if entityState and entityState.Position and entityState.Radius > maxRadius then
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
			if entityState then
				entityState.CoveredCells = {}
				entityState.Separation = Vector2.zero
				if entityState.FlatPosition then
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

	function MovementService:_RemoveFlowSeparationEntity(entity: number)
		local runtime = self:_GetOrCreateFlowSeparationRuntime()
		local entityState = runtime.EntityStateById[entity]
		if not entityState then
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
end
