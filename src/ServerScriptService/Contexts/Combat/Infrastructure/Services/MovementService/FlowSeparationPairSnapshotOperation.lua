--!strict

local ServerScriptService = game:GetService("ServerScriptService")

local FlowSeparationPairSnapshotCodec = require(
	ServerScriptService.Contexts.Combat.Infrastructure.Services.MovementService.FlowSeparationPairSnapshotCodec
)

local OPERATION_NAME = "FlowSeparationPairSnapshotBuild"

local FlowSeparationPairSnapshotOperation = {
	Name = OPERATION_NAME,
	CacheLocalMemory = true,
	ResultSchema = {
		{ Name = "PairCount", Type = "u16" },
		{ Name = "Overflow", Type = "boolean" },
		{ Name = "PairsBuffer", Type = "buffer", Length = FlowSeparationPairSnapshotCodec.PAIR_BUFFER_LENGTH },
	},
}

local function _EmptyRow()
	return {
		PairCount = 0,
		Overflow = false,
		PairsBuffer = buffer.create(FlowSeparationPairSnapshotCodec.PAIR_BUFFER_LENGTH),
	}
end

function FlowSeparationPairSnapshotOperation.Execute(taskId: number, memory: SharedTable?)
	if memory == nil then
		return _EmptyRow()
	end

	local cellEntityStarts = memory.CellEntityStarts
	local cellEntityCounts = memory.CellEntityCounts
	local eligibleEntityIds = memory.EligibleEntityIds
	if cellEntityStarts == nil or cellEntityCounts == nil or eligibleEntityIds == nil then
		return _EmptyRow()
	end

	local cellStart = cellEntityStarts[taskId]
	local cellCount = cellEntityCounts[taskId]
	if type(cellStart) ~= "number" or type(cellCount) ~= "number" or cellCount < 2 then
		return _EmptyRow()
	end

	local encodedPairs = buffer.create(FlowSeparationPairSnapshotCodec.PAIR_BUFFER_LENGTH)
	local pairCount = 0

	for index = 0, cellCount - 2 do
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
			if pairCount > FlowSeparationPairSnapshotCodec.MAX_PAIRS_PER_TASK then
				return {
					PairCount = FlowSeparationPairSnapshotCodec.MAX_PAIRS_PER_TASK,
					Overflow = true,
					PairsBuffer = encodedPairs,
				}
			end

			FlowSeparationPairSnapshotCodec.WritePair(encodedPairs, pairCount, entityA, entityB)
		end
	end

	return {
		PairCount = pairCount,
		Overflow = false,
		PairsBuffer = encodedPairs,
	}
end

return table.freeze(FlowSeparationPairSnapshotOperation)
