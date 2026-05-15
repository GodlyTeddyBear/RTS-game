--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Query = require(ReplicatedStorage.Utilities.MuchachoHitbox.src.Query)

local OPERATION_NAME = "MuchachoHitboxPresence"

local ParallelPresenceOperation = {
	Name = OPERATION_NAME,
	CacheLocalMemory = true,
	ResultSchema = {
		{ Name = "HitboxIndex", Type = "u32" },
		{ Name = "HasAny", Type = "boolean" },
	},
}

local function _EmptyRow(hitboxIndex: number)
	return {
		HitboxIndex = hitboxIndex,
		HasAny = false,
	}
end

function ParallelPresenceOperation.Execute(taskId: number, memory: SharedTable?)
	if memory == nil then
		return _EmptyRow(taskId)
	end

	local queryCFrames = memory.QueryCFrames
	local sizes = memory.Sizes
	local shapeIds = memory.ShapeIds
	local filterTokens = memory.FilterTokens
	if queryCFrames == nil or sizes == nil or shapeIds == nil or filterTokens == nil then
		return _EmptyRow(taskId)
	end

	local queryCFrame = queryCFrames[taskId]
	local size = sizes[taskId]
	local shapeId = shapeIds[taskId]
	local filterToken = filterTokens[taskId]
	if typeof(queryCFrame) ~= "CFrame" or typeof(size) ~= "Vector3" then
		return _EmptyRow(taskId)
	end
	if type(shapeId) ~= "number" or type(filterToken) ~= "string" then
		return _EmptyRow(taskId)
	end

	return {
		HitboxIndex = taskId,
		HasAny = Query.CastParallelPresenceQuery(queryCFrame, size, shapeId, filterToken),
	}
end

return table.freeze(ParallelPresenceOperation)
