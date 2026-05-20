--!strict

local ServerScriptService = game:GetService("ServerScriptService")

local FlowSeparationMath =
	require(ServerScriptService.Contexts.Combat.Infrastructure.Services.MovementService.Math.FlowSeparationMath)

local function _HasCoreSharedMemoryFields(memory: SharedTable): boolean
	return not not (
		memory.GoalGroupCellRecordStartIndex
		and memory.GoalGroupCellRecordCount
		and memory.GoalGroupCellWidthStuds
		and memory.GroupCellX
		and memory.GroupCellY
		and memory.CellPackedKey
		and memory.CellMemberStartIndex
		and memory.CellMemberCount
		and memory.CellMemberEntityIndex
		and memory.FlatPositionX
		and memory.FlatPositionY
		and memory.Radius
		and memory.FlowVelocityX
		and memory.FlowVelocityY
		and memory.PreviousVelocityX
		and memory.PreviousVelocityY
		and memory.WalkSpeed
		and memory.VelAlpha
		and memory.IsSettled
		and memory.WallPackedKeys
	)
end

local Worker = {}

function Worker.Execute(request)
	local memory = request.SharedMemory
	if not memory then
		return {}
	end

	local entityCount = memory.EntityCount
	if type(entityCount) ~= "number" or not _HasCoreSharedMemoryFields(memory) then
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
			GoalGroupCellRecordStartIndex = memory.GoalGroupCellRecordStartIndex,
			GoalGroupCellRecordCount = memory.GoalGroupCellRecordCount,
			GoalGroupCellWidthStuds = memory.GoalGroupCellWidthStuds,
			GroupCellX = memory.GroupCellX,
			GroupCellY = memory.GroupCellY,
			CellPackedKey = memory.CellPackedKey,
			CellMemberStartIndex = memory.CellMemberStartIndex,
			CellMemberCount = memory.CellMemberCount,
			CellMemberEntityIndex = memory.CellMemberEntityIndex,
			FlatPositionX = memory.FlatPositionX,
			FlatPositionY = memory.FlatPositionY,
			Radius = memory.Radius,
			FlowVelocityX = memory.FlowVelocityX,
			FlowVelocityY = memory.FlowVelocityY,
			PreviousVelocityX = memory.PreviousVelocityX,
			PreviousVelocityY = memory.PreviousVelocityY,
			WalkSpeed = memory.WalkSpeed,
			VelAlpha = memory.VelAlpha,
			IsSettled = memory.IsSettled,
			WallPackedKeys = memory.WallPackedKeys,
			DeltaTime = (type(memory.DeltaTime) == "number") and memory.DeltaTime or 0,
			CellWidthStuds = (type(memory.CellWidthStuds) == "number") and memory.CellWidthStuds or 1,
			OriginX = (type(memory.OriginX) == "number") and memory.OriginX or 0,
			OriginY = (type(memory.OriginY) == "number") and memory.OriginY or 0,
			WallGridHalfSize = (type(memory.WallGridHalfSize) == "number") and memory.WallGridHalfSize or nil,
			KForce = (type(memory.KForce) == "number") and memory.KForce or 80,
			MinSeparationDistance = (type(memory.MinSeparationDistance) == "number") and memory.MinSeparationDistance
				or 1e-4,
			WallCollisionEnabled = memory.WallCollisionEnabled == true,
			WallCollisionAxisClampEnabled = memory.WallCollisionAxisClampEnabled == true,
			WallCollisionCornerClampEnabled = memory.WallCollisionCornerClampEnabled == true,
			WallCollisionUseUnitRadiusPadding = memory.WallCollisionUseUnitRadiusPadding == true,
			WallCollisionCellProbePaddingStuds = (type(memory.WallCollisionCellProbePaddingStuds) == "number")
					and memory.WallCollisionCellProbePaddingStuds
				or 0,
			WallCollisionVelocityEpsilon = (type(memory.WallCollisionVelocityEpsilon) == "number")
					and memory.WallCollisionVelocityEpsilon
				or 1e-4,
			ClumpTouchPaddingStuds = (type(memory.ClumpTouchPaddingStuds) == "number") and memory.ClumpTouchPaddingStuds
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
