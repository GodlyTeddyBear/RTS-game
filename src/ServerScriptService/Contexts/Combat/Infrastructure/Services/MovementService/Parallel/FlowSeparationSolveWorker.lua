--!strict

local ServerScriptService = game:GetService("ServerScriptService")

local FlowSeparationMath =
	require(ServerScriptService.Contexts.Combat.Infrastructure.Services.MovementService.Math.FlowSeparationMath)
local MovementTypes = require(ServerScriptService.Contexts.Combat.Infrastructure.Services.MovementService.Types)

type TFlowSeparationWorkerRequest = MovementTypes.TFlowSeparationWorkerRequest
type TFlowSeparationWorkerSharedMemory = MovementTypes.TFlowSeparationWorkerSharedMemory
type TFlowSeparationWorkerPayload = MovementTypes.TFlowSeparationWorkerPayload

local function _HasCoreSharedMemoryFields(memory: TFlowSeparationWorkerSharedMemory): boolean
	return memory.WallGrid ~= nil and type(memory.WallGridWidth) == "number"
end

local function _HasCoreWorkerPayloadFields(payload: TFlowSeparationWorkerPayload): boolean
	return not not (
		payload.GoalGroupCellRecordStartIndex
		and payload.GoalGroupCellRecordCount
		and payload.GoalGroupCellLookupStartIndex
		and payload.GoalGroupCellLookupCount
		and payload.GoalGroupCellWidthStuds
		and payload.GroupCellX
		and payload.GroupCellY
		and payload.CellPackedKey
		and payload.CellMemberStartIndex
		and payload.CellMemberCount
		and payload.CellMemberEntityIndex
		and payload.LookupPackedKey
		and payload.LookupCellRecordIndex
		and payload.FlatPositionX
		and payload.FlatPositionY
		and payload.Radius
		and payload.FlowVelocityX
		and payload.FlowVelocityY
		and payload.PreviousVelocityX
		and payload.PreviousVelocityY
		and payload.WalkSpeed
		and payload.VelAlpha
		and payload.IsSettled
	)
end

local Worker = {}

function Worker.Execute(request: TFlowSeparationWorkerRequest)
	local shared = request.SharedMemory
	local payload = request.WorkerPayload
	if not shared or not payload then
		return {}
	end

	local entityCount = payload.EntityCount
	if type(entityCount) ~= "number" or not _HasCoreSharedMemoryFields(shared) or not _HasCoreWorkerPayloadFields(payload) then
		return {}
	end

	local resolvedLogicalWorkCount = math.min(request.LogicalWorkCount, entityCount)
	local rows = {}

	for offset = 0, request.BatchSize - 1 do
		local entityIndex = request.StartTaskId + offset
		if entityIndex > resolvedLogicalWorkCount then
			break
		end

		local velocity, touchedSettledNeighbor = FlowSeparationMath.ResolveVelocityWithWalls({
			EntityIndex = entityIndex,
			GoalGroupCellRecordStartIndex = payload.GoalGroupCellRecordStartIndex,
			GoalGroupCellRecordCount = payload.GoalGroupCellRecordCount,
			GoalGroupCellLookupStartIndex = payload.GoalGroupCellLookupStartIndex,
			GoalGroupCellLookupCount = payload.GoalGroupCellLookupCount,
			GoalGroupCellWidthStuds = payload.GoalGroupCellWidthStuds,
			GroupCellX = payload.GroupCellX,
			GroupCellY = payload.GroupCellY,
			CellPackedKey = payload.CellPackedKey,
			CellMemberStartIndex = payload.CellMemberStartIndex,
			CellMemberCount = payload.CellMemberCount,
			CellMemberEntityIndex = payload.CellMemberEntityIndex,
			LookupPackedKey = payload.LookupPackedKey,
			LookupCellRecordIndex = payload.LookupCellRecordIndex,
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
			WallGrid = shared.WallGrid,
			DeltaTime = (type(payload.DeltaTime) == "number") and payload.DeltaTime or 0,
			CellWidthStuds = (type(shared.CellWidthStuds) == "number") and shared.CellWidthStuds or 1,
			OriginX = (type(shared.OriginX) == "number") and shared.OriginX or 0,
			OriginY = (type(shared.OriginY) == "number") and shared.OriginY or 0,
			WallGridHalfSize = (type(shared.WallGridHalfSize) == "number") and shared.WallGridHalfSize or nil,
			WallGridWidth = (type(shared.WallGridWidth) == "number") and shared.WallGridWidth or nil,
			KForce = (type(shared.KForce) == "number") and shared.KForce or 80,
			MinSeparationDistance = (type(shared.MinSeparationDistance) == "number") and shared.MinSeparationDistance
				or 1e-4,
			WallCollisionEnabled = shared.WallCollisionEnabled == true,
			WallCollisionAxisClampEnabled = shared.WallCollisionAxisClampEnabled == true,
			WallCollisionCornerClampEnabled = shared.WallCollisionCornerClampEnabled == true,
			WallCollisionUseUnitRadiusPadding = shared.WallCollisionUseUnitRadiusPadding == true,
			WallCollisionCellProbePaddingStuds = (type(shared.WallCollisionCellProbePaddingStuds) == "number")
					and shared.WallCollisionCellProbePaddingStuds
				or 0,
			WallCollisionVelocityEpsilon = (type(shared.WallCollisionVelocityEpsilon) == "number")
					and shared.WallCollisionVelocityEpsilon
				or 1e-4,
			ClumpTouchPaddingStuds = (type(shared.ClumpTouchPaddingStuds) == "number") and shared.ClumpTouchPaddingStuds
				or 0,
		})

		rows[#rows + 1] = {
			EntityIndex = entityIndex,
			VelocityX = velocity.X,
			VelocityY = velocity.Y,
			TouchedSettledNeighbor = touchedSettledNeighbor,
		}
	end

	return rows
end

return Worker
