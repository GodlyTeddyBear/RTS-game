--!strict

local ServerScriptService = game:GetService("ServerScriptService")

local MovementMath =
	require(ServerScriptService.Contexts.Combat.Infrastructure.Services.MovementService.Math.MovementMath)
local MovementTypes = require(ServerScriptService.Contexts.Combat.Infrastructure.Services.MovementService.Types)

type TFlowSeparationManagerPayload = MovementTypes.TFlowSeparationManagerPayload
type TFlowSeparationWorkerPayload = MovementTypes.TFlowSeparationWorkerPayload

local function _ResolveGroupCellWidth(entityIndices: { number }, radiusByEntityIndex: { number }): number
	local maxRadius = 0
	for _, entityIndex in ipairs(entityIndices) do
		local radius = radiusByEntityIndex[entityIndex]
		if type(radius) == "number" and radius > maxRadius then
			maxRadius = radius
		end
	end

	return math.max(4, maxRadius * 2)
end

local function _AppendCellRecords(
	entityIndices: { number },
	groupCellWidthStuds: number,
	payload: TFlowSeparationManagerPayload,
	goalGroupCellRecordStartIndex: { number },
	goalGroupCellRecordCount: { number },
	goalGroupCellLookupStartIndex: { number },
	goalGroupCellLookupCount: { number },
	groupCellX: { number },
	groupCellY: { number },
	cellPackedKey: { number },
	cellMemberStartIndex: { number },
	cellMemberCount: { number },
	cellMemberEntityIndex: { number },
	lookupPackedKey: { number },
	lookupCellRecordIndex: { number },
	radiusByEntityIndex: { number }
)
	local bucketsByPackedKey = {} :: { [number]: { number } }
	local packedKeys = {} :: { number }

	for _, entityIndex in ipairs(entityIndices) do
		local flatPosition = Vector2.new(payload.FlatPositionX[entityIndex], payload.FlatPositionY[entityIndex])
		local cellX, cellY = MovementMath.FlatPositionToCell(flatPosition, groupCellWidthStuds)
		local packedKey = MovementMath.PackedSeparationCellKey(cellX, cellY)

		groupCellX[entityIndex] = cellX
		groupCellY[entityIndex] = cellY
		radiusByEntityIndex[entityIndex] = payload.Radius[entityIndex]

		local bucket = bucketsByPackedKey[packedKey]
		if bucket == nil then
			bucket = {}
			bucketsByPackedKey[packedKey] = bucket
			packedKeys[#packedKeys + 1] = packedKey
		end

		bucket[#bucket + 1] = entityIndex
	end

	table.sort(packedKeys)

	local recordStartIndex = #cellPackedKey + 1
	local recordCount = #packedKeys
	local lookupStartIndex = #lookupPackedKey + 1
	local lookupCount = #packedKeys

	for _, entityIndex in ipairs(entityIndices) do
		goalGroupCellRecordStartIndex[entityIndex] = recordStartIndex
		goalGroupCellRecordCount[entityIndex] = recordCount
		goalGroupCellLookupStartIndex[entityIndex] = lookupStartIndex
		goalGroupCellLookupCount[entityIndex] = lookupCount
	end

	for _, packedKey in ipairs(packedKeys) do
		local bucket = bucketsByPackedKey[packedKey]
		if bucket ~= nil then
			local recordIndex = #cellPackedKey + 1
			cellPackedKey[recordIndex] = packedKey
			cellMemberStartIndex[recordIndex] = #cellMemberEntityIndex + 1
			cellMemberCount[recordIndex] = #bucket
			lookupPackedKey[#lookupPackedKey + 1] = packedKey
			lookupCellRecordIndex[#lookupCellRecordIndex + 1] = recordIndex

			for _, entityIndex in ipairs(bucket) do
				cellMemberEntityIndex[#cellMemberEntityIndex + 1] = entityIndex
			end
		end
	end
end

local Manager = {}

function Manager.BuildDispatch(request: { ManagerPayload: TFlowSeparationManagerPayload? })
	local payload = request.ManagerPayload
	if payload == nil then
		return {
			LogicalWorkCount = 0,
			WorkerPayload = {
				EntityCount = 0,
				DeltaTime = 0,
				GoalGroupCellRecordStartIndex = {},
				GoalGroupCellRecordCount = {},
				GoalGroupCellLookupStartIndex = {},
				GoalGroupCellLookupCount = {},
				GoalGroupCellWidthStuds = {},
				GroupCellX = {},
				GroupCellY = {},
				CellPackedKey = {},
				CellMemberStartIndex = {},
				CellMemberCount = {},
				CellMemberEntityIndex = {},
				LookupPackedKey = {},
				LookupCellRecordIndex = {},
				FlatPositionX = {},
				FlatPositionY = {},
				Radius = {},
				FlowVelocityX = {},
				FlowVelocityY = {},
				PreviousVelocityX = {},
				PreviousVelocityY = {},
				WalkSpeed = {},
				VelAlpha = {},
				IsSettled = {},
			},
		}
	end

	local entityCount = #payload.EntityIds
	local goalGroupCellRecordStartIndex = table.create(entityCount, 0)
	local goalGroupCellRecordCount = table.create(entityCount, 0)
	local goalGroupCellLookupStartIndex = table.create(entityCount, 0)
	local goalGroupCellLookupCount = table.create(entityCount, 0)
	local goalGroupCellWidthStuds = table.create(entityCount, 0)
	local groupCellX = table.create(entityCount, 0)
	local groupCellY = table.create(entityCount, 0)
	local cellPackedKey = {} :: { number }
	local cellMemberStartIndex = {} :: { number }
	local cellMemberCount = {} :: { number }
	local cellMemberEntityIndex = {} :: { number }
	local lookupPackedKey = {} :: { number }
	local lookupCellRecordIndex = {} :: { number }
	local entityIndicesByGoalKey = {} :: { [string]: { number } }
	local activeGoalKeys = {} :: { string }
	local radiusByEntityIndex = table.create(entityCount, 0)

	for entityIndex = 1, entityCount do
		local goalKey = payload.GoalKeys[entityIndex]
		local entityIndices = entityIndicesByGoalKey[goalKey]
		if entityIndices == nil then
			entityIndices = {}
			entityIndicesByGoalKey[goalKey] = entityIndices
			activeGoalKeys[#activeGoalKeys + 1] = goalKey
		end

		entityIndices[#entityIndices + 1] = entityIndex
		radiusByEntityIndex[entityIndex] = payload.Radius[entityIndex]
	end

	for _, goalKey in ipairs(activeGoalKeys) do
		local entityIndices = entityIndicesByGoalKey[goalKey]
		if entityIndices ~= nil and #entityIndices > 0 then
			local groupWidth = _ResolveGroupCellWidth(entityIndices, radiusByEntityIndex)
			for _, entityIndex in ipairs(entityIndices) do
				goalGroupCellWidthStuds[entityIndex] = groupWidth
			end

			_AppendCellRecords(
				entityIndices,
				groupWidth,
				payload,
				goalGroupCellRecordStartIndex,
				goalGroupCellRecordCount,
				goalGroupCellLookupStartIndex,
				goalGroupCellLookupCount,
				groupCellX,
				groupCellY,
				cellPackedKey,
				cellMemberStartIndex,
				cellMemberCount,
				cellMemberEntityIndex,
				lookupPackedKey,
				lookupCellRecordIndex,
				radiusByEntityIndex
			)
		end
	end

	local workerPayload: TFlowSeparationWorkerPayload = {
		EntityCount = entityCount,
		DeltaTime = payload.DeltaTime,
		GoalGroupCellRecordStartIndex = goalGroupCellRecordStartIndex,
		GoalGroupCellRecordCount = goalGroupCellRecordCount,
		GoalGroupCellLookupStartIndex = goalGroupCellLookupStartIndex,
		GoalGroupCellLookupCount = goalGroupCellLookupCount,
		GoalGroupCellWidthStuds = goalGroupCellWidthStuds,
		GroupCellX = groupCellX,
		GroupCellY = groupCellY,
		CellPackedKey = cellPackedKey,
		CellMemberStartIndex = cellMemberStartIndex,
		CellMemberCount = cellMemberCount,
		CellMemberEntityIndex = cellMemberEntityIndex,
		LookupPackedKey = lookupPackedKey,
		LookupCellRecordIndex = lookupCellRecordIndex,
		FlatPositionX = payload.FlatPositionX,
		FlatPositionY = payload.FlatPositionY,
		Radius = payload.Radius,
		FlowVelocityX = payload.FlowVelocityX,
		FlowVelocityY = payload.FlowVelocityY,
		PreviousVelocityX = payload.PreviousVelocityX,
		PreviousVelocityY = payload.PreviousVelocityY,
		WalkSpeed = payload.WalkSpeed,
		VelAlpha = payload.VelAlpha,
		IsSettled = payload.IsSettled,
	}

	return {
		LogicalWorkCount = entityCount,
		WorkerPayload = workerPayload,
	}
end

return Manager
