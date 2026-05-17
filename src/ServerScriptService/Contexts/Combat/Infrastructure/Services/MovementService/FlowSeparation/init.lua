--!strict

return function(MovementService: any)
	require(script.Config)(MovementService)
	require(script.RuntimeState)(MovementService)
	require(script.SpatialState)(MovementService)
	require(script.ParallelRuntime)(MovementService)
	require(script.SnapshotBuild)(MovementService)
	require(script.PairApply)(MovementService)

	function MovementService:_RecomputeDirtyFlowSeparation(sepConfig: any)
		local runtime = self:_GetOrCreateFlowSeparationRuntime()
		self:_ApplyCompletedFlowSeparationPairAsyncResult(sepConfig)
		local completedPairSnapshot = self:_ApplyCompletedFlowSeparationPairSnapshotBuildAsyncResult(sepConfig)
		if completedPairSnapshot then
			self:_ResolveFlowSeparationPairSnapshot(completedPairSnapshot, sepConfig, true)
		end

		if not next(runtime.DirtyEntities) and not next(runtime.DirtyCells) then
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
			if entityState then
				for _, coveredCell in ipairs(entityState.CoveredCells) do
					candidateCellSet[coveredCell.Key] = true
				end
			end
		end

		for candidateCellKey in candidateCellSet do
			local bucket = runtime.BucketsByCell[candidateCellKey]
			if bucket then
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
			if entityState then
				entityState.Separation = Vector2.zero
			end
			runtime.ActiveSolveEntities[entityId] = nil
		end

		local activeSolveEntitySet, activeSolveEntities = self:_BuildFlowSeparationSolveSet(recomputedEntities, sepConfig)
		for _, entityId in ipairs(activeSolveEntities) do
			runtime.ActiveSolveEntities[entityId] = true
		end

		local kForce = (type(sepConfig.KForce) == "number" and sepConfig.KForce) or 80
		local minSeparationDistance = (type(sepConfig.MinSeparationDistance) == "number" and sepConfig.MinSeparationDistance)
			or 1e-4
		local denseFallbackEntitySet: { [number]: boolean } = {}

		if self:_UseDenseCellFallback(sepConfig) then
			local denseCellThreshold = self:_GetDenseCellOccupancyThreshold(sepConfig)
			for candidateCellKey in candidateCellSet do
				local bucket = runtime.BucketsByCell[candidateCellKey]
				if bucket then
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
							if entityState and entityState.FlatPosition then
								center += entityState.FlatPosition
								denseFallbackEntitySet[entityId] = true
							end
						end

						center = center / #activeCellEntities
						for _, entityId in ipairs(activeCellEntities) do
							local entityState = runtime.EntityStateById[entityId]
							if entityState and entityState.FlatPosition then
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
		return (entityState and entityState.Separation) or Vector2.zero
	end
end
