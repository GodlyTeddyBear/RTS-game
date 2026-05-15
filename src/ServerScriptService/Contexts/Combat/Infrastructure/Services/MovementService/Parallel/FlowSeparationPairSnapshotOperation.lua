--!strict

local ServerScriptService = game:GetService("ServerScriptService")

local FlowSeparationPairSnapshotCodec = require(
	ServerScriptService.Contexts.Combat.Infrastructure.Services.MovementService.Parallel.FlowSeparationPairSnapshotCodec
)
local FlowSeparationPairSnapshotSchema = require(
	ServerScriptService.Contexts.Combat.Infrastructure.Services.MovementService.Parallel.FlowSeparationPairSnapshotSchema
)

local OPERATION_NAME = "FlowSeparationPairSnapshotBuild"

local FlowSeparationPairSnapshotOperation = {
	Name = OPERATION_NAME,
	CacheLocalMemory = true,
	ResultSchema = FlowSeparationPairSnapshotSchema.RESULT_SCHEMA,
}

local function _EmptyRow()
	return {
		PairCount = 0,
		Overflow = false,
	}
end

function FlowSeparationPairSnapshotOperation.Execute(taskId: number, memory: SharedTable?)
	if memory == nil then
		return _EmptyRow()
	end

	local eligibleEntityIds = memory.EligibleEntityIds
	local taskCellIndices = memory.TaskCellIndices
	local taskOuterStartOffsets = memory.TaskOuterStartOffsets
	local taskOuterEndOffsets = memory.TaskOuterEndOffsets
	local taskEntityStartIndices = memory.TaskEntityStartIndices
	local taskEntityCounts = memory.TaskEntityCounts
	if eligibleEntityIds == nil
		or taskCellIndices == nil
		or taskOuterStartOffsets == nil
		or taskOuterEndOffsets == nil
		or taskEntityStartIndices == nil
		or taskEntityCounts == nil
	then
		return _EmptyRow()
	end

	local _cellIndex = taskCellIndices[taskId]
	local cellStart = taskEntityStartIndices[taskId]
	local cellCount = taskEntityCounts[taskId]
	local outerStartOffset = taskOuterStartOffsets[taskId]
	local outerEndOffset = taskOuterEndOffsets[taskId]
	if type(_cellIndex) ~= "number"
		or type(cellStart) ~= "number"
		or type(cellCount) ~= "number"
		or type(outerStartOffset) ~= "number"
		or type(outerEndOffset) ~= "number"
		or cellCount < 2
	then
		return _EmptyRow()
	end

	local maxPairsPerTask = FlowSeparationPairSnapshotSchema.GetFixedMaxPairsPerTask()
	local row = _EmptyRow()
	local pairCount = 0

	for index = outerStartOffset, math.min(outerEndOffset, cellCount - 2) do
		local entityA = eligibleEntityIds[cellStart + index]
		if type(entityA) ~= "number" then
			continue
		end

		for otherIndex = index + 1, cellCount - 1 do
			local entityB = eligibleEntityIds[cellStart + otherIndex]
			if type(entityB) ~= "number" then
				continue
			end

			pairCount += 1
			if pairCount > maxPairsPerTask then
				row.PairCount = maxPairsPerTask
				row.Overflow = true
				return row
			end

			FlowSeparationPairSnapshotCodec.WritePair(row, pairCount, entityA, entityB)
		end
	end

	row.PairCount = pairCount
	return row
end

return table.freeze(FlowSeparationPairSnapshotOperation)
