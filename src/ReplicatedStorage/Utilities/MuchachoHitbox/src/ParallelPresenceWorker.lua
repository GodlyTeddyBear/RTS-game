--!strict
--!optimize 2

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Query = require(ReplicatedStorage.Utilities.MuchachoHitbox.src.Query)

local Worker = {}

local function _EmptyRow(hitboxIndex: number)
	return {
		HitboxIndex = hitboxIndex,
		HasAny = false,
	}
end

function Worker.Execute(request)
	local payload = request.WorkerPayload
	if payload == nil then
		return {}
	end

	local queryCFrames = payload.QueryCFrames
	local sizes = payload.Sizes
	local shapeIds = payload.ShapeIds
	local filterTokens = payload.FilterTokens
	if queryCFrames == nil or sizes == nil or shapeIds == nil or filterTokens == nil then
		return {}
	end

	local resolvedLogicalWorkCount = math.min(request.LogicalWorkCount, #queryCFrames, #sizes, #shapeIds, #filterTokens)
	local rows = {}

	for offset = 0, request.BatchSize - 1 do
		local hitboxIndex = request.StartTaskId + offset
		if hitboxIndex > resolvedLogicalWorkCount then
			break
		end

		local queryCFrame = queryCFrames[hitboxIndex]
		local size = sizes[hitboxIndex]
		local shapeId = shapeIds[hitboxIndex]
		local filterToken = filterTokens[hitboxIndex]
		if typeof(queryCFrame) ~= "CFrame" or typeof(size) ~= "Vector3" then
			rows[#rows + 1] = _EmptyRow(hitboxIndex)
			continue
		end
		if type(shapeId) ~= "number" or type(filterToken) ~= "string" then
			rows[#rows + 1] = _EmptyRow(hitboxIndex)
			continue
		end

		rows[#rows + 1] = {
			HitboxIndex = hitboxIndex,
			HasAny = Query.CastParallelPresenceQuery(queryCFrame, size, shapeId, filterToken),
		}
	end

	return rows
end

return Worker
