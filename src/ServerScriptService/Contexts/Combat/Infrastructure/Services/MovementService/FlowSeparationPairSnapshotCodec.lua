--!strict

local FlowSeparationPairSnapshotCodec = {}

FlowSeparationPairSnapshotCodec.MAX_PAIRS_PER_TASK = 128
FlowSeparationPairSnapshotCodec.BYTES_PER_PAIR = 8
FlowSeparationPairSnapshotCodec.PAIR_BUFFER_LENGTH =
	FlowSeparationPairSnapshotCodec.MAX_PAIRS_PER_TASK * FlowSeparationPairSnapshotCodec.BYTES_PER_PAIR

function FlowSeparationPairSnapshotCodec.GetMaxSupportedEntityCountPerCell(): number
	local maxPairs = FlowSeparationPairSnapshotCodec.MAX_PAIRS_PER_TASK
	return math.floor((1 + math.sqrt(1 + 8 * maxPairs)) / 2)
end

function FlowSeparationPairSnapshotCodec.WritePair(targetBuffer: buffer, pairIndex: number, entityA: number, entityB: number)
	local offset = (pairIndex - 1) * FlowSeparationPairSnapshotCodec.BYTES_PER_PAIR
	buffer.writeu32(targetBuffer, offset, entityA)
	buffer.writeu32(targetBuffer, offset + 4, entityB)
end

function FlowSeparationPairSnapshotCodec.ReadPair(targetBuffer: buffer, pairIndex: number): (number, number)
	local offset = (pairIndex - 1) * FlowSeparationPairSnapshotCodec.BYTES_PER_PAIR
	return buffer.readu32(targetBuffer, offset), buffer.readu32(targetBuffer, offset + 4)
end

return table.freeze(FlowSeparationPairSnapshotCodec)
