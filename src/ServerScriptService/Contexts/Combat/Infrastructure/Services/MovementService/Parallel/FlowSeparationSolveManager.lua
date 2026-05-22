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

local function _NextPowerOfTwo(value: number): number
	local power = 1
	while power < value do
		power *= 2
	end
	return power
end

local function _InsertHashEntry(
	cellHashPackedKey: { number },
	cellHashRecordIndex: { number },
	hashStartIndex: number,
	hashSlotCount: number,
	packedKey: number,
	recordIndex: number
)
	local slotMask = hashSlotCount - 1
	local slotOffset = bit32.band(packedKey, slotMask)

	for _ = 1, hashSlotCount do
		local hashIndex = hashStartIndex + slotOffset
		if cellHashRecordIndex[hashIndex] == 0 then
			cellHashPackedKey[hashIndex] = packedKey
			cellHashRecordIndex[hashIndex] = recordIndex
			return
		end

		slotOffset = bit32.band(slotOffset + 1, slotMask)
	end

	error(`FlowSeparation hash table overflow for packed key {packedKey}`)
end

local function _AppendCellRecords(
	entityIndices: { number },
	groupCellWidthStuds: number,
	payload: TFlowSeparationManagerPayload,
	goalGroupCellRecordStartIndex: { number },
	goalGroupCellRecordCount: { number },
	goalGroupCellHashStartIndex: { number },
	goalGroupCellHashSlotCount: { number },
	groupCellX: { number },
	groupCellY: { number },
	cellPackedKey: { number },
	cellMemberStartIndex: { number },
	cellMemberCount: { number },
	cellMemberEntityIndex: { number },
	cellHashPackedKey: { number },
	cellHashRecordIndex: { number },
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

	-- Disabled because it is unnecessary overhead
	--table.sort(packedKeys)

	local recordStartIndex = #cellPackedKey + 1
	local recordCount = #packedKeys
	local hashSlotCount = math.max(8, _NextPowerOfTwo(recordCount * 2))
	local hashStartIndex = #cellHashPackedKey + 1

	for _, entityIndex in ipairs(entityIndices) do
		goalGroupCellRecordStartIndex[entityIndex] = recordStartIndex
		goalGroupCellRecordCount[entityIndex] = recordCount
		goalGroupCellHashStartIndex[entityIndex] = hashStartIndex
		goalGroupCellHashSlotCount[entityIndex] = hashSlotCount
	end

	for _ = 1, hashSlotCount do
		cellHashPackedKey[#cellHashPackedKey + 1] = 0
		cellHashRecordIndex[#cellHashRecordIndex + 1] = 0
	end

	for _, packedKey in ipairs(packedKeys) do
		local bucket = bucketsByPackedKey[packedKey]
		if bucket ~= nil then
			local recordIndex = #cellPackedKey + 1
			cellPackedKey[recordIndex] = packedKey
			cellMemberStartIndex[recordIndex] = #cellMemberEntityIndex + 1
			cellMemberCount[recordIndex] = #bucket
			_InsertHashEntry(
				cellHashPackedKey,
				cellHashRecordIndex,
				hashStartIndex,
				hashSlotCount,
				packedKey,
				recordIndex
			)

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
				GoalGroupCellHashStartIndex = {},
				GoalGroupCellHashSlotCount = {},
				GoalGroupCellWidthStuds = {},
				GroupCellX = {},
				GroupCellY = {},
				CellPackedKey = {},
				CellMemberStartIndex = {},
				CellMemberCount = {},
				CellMemberEntityIndex = {},
				CellHashPackedKey = {},
				CellHashRecordIndex = {},
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
	local goalGroupCellHashStartIndex = table.create(entityCount, 0)
	local goalGroupCellHashSlotCount = table.create(entityCount, 0)
	local goalGroupCellWidthStuds = table.create(entityCount, 0)
	local groupCellX = table.create(entityCount, 0)
	local groupCellY = table.create(entityCount, 0)
	local cellPackedKey = {} :: { number }
	local cellMemberStartIndex = {} :: { number }
	local cellMemberCount = {} :: { number }
	local cellMemberEntityIndex = {} :: { number }
	local cellHashPackedKey = {} :: { number }
	local cellHashRecordIndex = {} :: { number }
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
				goalGroupCellHashStartIndex,
				goalGroupCellHashSlotCount,
				groupCellX,
				groupCellY,
				cellPackedKey,
				cellMemberStartIndex,
				cellMemberCount,
				cellMemberEntityIndex,
				cellHashPackedKey,
				cellHashRecordIndex,
				radiusByEntityIndex
			)
		end
	end

	local workerPayload: TFlowSeparationWorkerPayload = {
		EntityCount = entityCount,
		DeltaTime = payload.DeltaTime,
		GoalGroupCellRecordStartIndex = goalGroupCellRecordStartIndex,
		GoalGroupCellRecordCount = goalGroupCellRecordCount,
		GoalGroupCellHashStartIndex = goalGroupCellHashStartIndex,
		GoalGroupCellHashSlotCount = goalGroupCellHashSlotCount,
		GoalGroupCellWidthStuds = goalGroupCellWidthStuds,
		GroupCellX = groupCellX,
		GroupCellY = groupCellY,
		CellPackedKey = cellPackedKey,
		CellMemberStartIndex = cellMemberStartIndex,
		CellMemberCount = cellMemberCount,
		CellMemberEntityIndex = cellMemberEntityIndex,
		CellHashPackedKey = cellHashPackedKey,
		CellHashRecordIndex = cellHashRecordIndex,
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
