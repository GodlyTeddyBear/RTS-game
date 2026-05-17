--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ParallelQuery = require(ReplicatedStorage.Utilities.ParallelQuery)
local MovementTypes = require(script.Parent.Parent.Types)
local FlowSeparationTypes = require(script.Parent.Types)
local FlowSeparationPairSnapshotCodec = require(script.Parent.Parent.Parallel.FlowSeparationPairSnapshotCodec)
local FlowSeparationPairSnapshotSchema = require(script.Parent.Parent.Parallel.FlowSeparationPairSnapshotSchema)

local ResultReduction = ParallelQuery.ResultReduction
local SharedMemoryAuthoring = ParallelQuery.SharedMemoryAuthoring
local ValidationHelpers = ParallelQuery.ValidationHelpers

type TFlowSeparationPairSnapshotBuildInput = MovementTypes.TFlowSeparationPairSnapshotBuildInput
type TFlowSeparationPairSnapshot = FlowSeparationTypes.TFlowSeparationPairSnapshot

return function(MovementService: any)
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
			if not bucket then
				continue
			end

			local cellEligibleStart = #input.EligibleEntityIds + 1
			local cellEligibleCount = 0

			for entityId in bucket do
				if activeSolveEntitySet[entityId] and not denseFallbackEntitySet[entityId] then
					local entityState = runtime.EntityStateById[entityId]
					if entityState and entityState.FlatPosition then
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
		local builder = SharedMemoryAuthoring.CreateSnapshotBuilder()
		SharedMemoryAuthoring.SetArrayValues(builder, "CellEntityStarts", input.CellEntityStarts)
		SharedMemoryAuthoring.SetArrayValues(builder, "CellEntityCounts", input.CellEntityCounts)
		SharedMemoryAuthoring.SetArrayValues(builder, "EligibleEntityIds", input.EligibleEntityIds)
		SharedMemoryAuthoring.SetArrayValues(builder, "TaskCellIndices", input.TaskCellIndices)
		SharedMemoryAuthoring.SetArrayValues(builder, "TaskOuterStartOffsets", input.TaskOuterStartOffsets)
		SharedMemoryAuthoring.SetArrayValues(builder, "TaskOuterEndOffsets", input.TaskOuterEndOffsets)
		SharedMemoryAuthoring.SetArrayValues(builder, "TaskEntityStartIndices", input.TaskEntityStartIndices)
		SharedMemoryAuthoring.SetArrayValues(builder, "TaskEntityCounts", input.TaskEntityCounts)
		return SharedMemoryAuthoring.BuildSharedMemory(builder)
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
			if entityIndex then
				return entityIndex
			end

			local positionX = input.EntityPositionXById[entityId]
			local positionY = input.EntityPositionYById[entityId]
			local radius = input.EntityRadiusById[entityId]
			if type(positionX) ~= "number" or type(positionY) ~= "number" or type(radius) ~= "number" then
				return
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
			if not entityIndexA or not entityIndexB then
				return
			end

			processedPairs[pairKey] = true
			table.insert(snapshot.PairA, entityIndexA)
			table.insert(snapshot.PairB, entityIndexB)
		end

		if not rows then
			return nil, false
		end

		local reduceState = {
			DidOverflow = false,
		}

		ResultReduction.Reduce(rows, reduceState, function(state, row, rowIndex)
			if state.DidOverflow then
				return false
			end

			local validationResult = ValidationHelpers.ValidateRowAgainstSchema(
				row,
				FlowSeparationPairSnapshotSchema.RESULT_SCHEMA,
				"Full",
				rowIndex
			)
			if not validationResult.IsValid then
				return false
			end

			if row.Overflow == true then
				state.DidOverflow = true
				return false
			end

			local pairCount = row.PairCount
			if type(pairCount) ~= "number" then
				return false
			end

			for pairIndex = 1, pairCount do
				local entityA, entityB = FlowSeparationPairSnapshotCodec.ReadPair(row, pairIndex)
				if entityA and entityB and entityA ~= 0 and entityB ~= 0 then
					appendPair(entityA, entityB)
				end
			end

			return true
		end)

		if reduceState.DidOverflow then
			return nil, true
		end

		self:_IncrementFastFlowProfileCounter("ParallelPairSnapshotBuilds")
		self:_IncrementFastFlowProfileCounter("ParallelPairSnapshotEntities", #snapshot.EntityIds)
		self:_IncrementFastFlowProfileCounter("ParallelPairSnapshotPairs", #snapshot.PairA)
		self:_IncrementFastFlowProfileCounter("ParallelPairSnapshotBuildMilliseconds", (os.clock() - buildStartedAt) * 1000)
		return snapshot, false
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
end
