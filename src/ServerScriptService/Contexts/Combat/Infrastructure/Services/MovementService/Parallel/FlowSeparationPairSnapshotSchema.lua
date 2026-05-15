--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ParallelQueryTypes = require(ReplicatedStorage.Utilities.ParallelQuery.src.Types)

type TResultField = ParallelQueryTypes.TResultField

local FlowSeparationPairSnapshotSchema = {}

FlowSeparationPairSnapshotSchema.FIXED_MAX_PAIRS_PER_TASK = 128
FlowSeparationPairSnapshotSchema.FIRST_PAIR_FIELD_INDEX = 3

local function _BuildPairFieldName(prefix: string, pairIndex: number): string
	return (`{prefix}_{pairIndex}`)
end

local mutableResultSchema: { TResultField } = {
	{ Name = "PairCount", Type = "u32" },
	{ Name = "Overflow", Type = "boolean" },
}

for pairIndex = 1, FlowSeparationPairSnapshotSchema.FIXED_MAX_PAIRS_PER_TASK do
	table.insert(mutableResultSchema, {
		Name = _BuildPairFieldName("EntityA", pairIndex),
		Type = "u32",
	})
	table.insert(mutableResultSchema, {
		Name = _BuildPairFieldName("EntityB", pairIndex),
		Type = "u32",
	})
end

local RESULT_SCHEMA: { TResultField } = table.freeze(mutableResultSchema)

FlowSeparationPairSnapshotSchema.RESULT_SCHEMA = RESULT_SCHEMA

function FlowSeparationPairSnapshotSchema.GetFixedMaxPairsPerTask(): number
	return FlowSeparationPairSnapshotSchema.FIXED_MAX_PAIRS_PER_TASK
end

function FlowSeparationPairSnapshotSchema.GetPairFieldNames(pairIndex: number): (string, string)
	assert(type(pairIndex) == "number" and pairIndex % 1 == 0 and pairIndex >= 1, "pairIndex must be a positive integer")
	assert(pairIndex <= FlowSeparationPairSnapshotSchema.GetFixedMaxPairsPerTask(), "pairIndex exceeds fixed pair capacity")
	return _BuildPairFieldName("EntityA", pairIndex), _BuildPairFieldName("EntityB", pairIndex)
end

return table.freeze(FlowSeparationPairSnapshotSchema)
