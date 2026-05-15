--!strict

local ServerScriptService = game:GetService("ServerScriptService")

local FlowSeparationPairSnapshotCodec = {}
local FlowSeparationPairSnapshotSchema = require(
	ServerScriptService.Contexts.Combat.Infrastructure.Services.MovementService.Parallel.FlowSeparationPairSnapshotSchema
)

function FlowSeparationPairSnapshotCodec.WritePair(row: { [string]: any }, pairIndex: number, entityA: number, entityB: number)
	local entityAFieldName, entityBFieldName = FlowSeparationPairSnapshotSchema.GetPairFieldNames(pairIndex)
	row[entityAFieldName] = entityA
	row[entityBFieldName] = entityB
end

function FlowSeparationPairSnapshotCodec.ReadPair(row: { [string]: any }, pairIndex: number): (number?, number?)
	local entityAFieldName, entityBFieldName = FlowSeparationPairSnapshotSchema.GetPairFieldNames(pairIndex)
	local entityA = row[entityAFieldName]
	local entityB = row[entityBFieldName]
	if type(entityA) ~= "number" or type(entityB) ~= "number" then
		return nil, nil
	end
	return entityA, entityB
end

return table.freeze(FlowSeparationPairSnapshotCodec)
