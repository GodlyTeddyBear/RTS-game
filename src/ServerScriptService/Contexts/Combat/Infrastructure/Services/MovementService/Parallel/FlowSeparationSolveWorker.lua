--!strict

local ServerScriptService = game:GetService("ServerScriptService")

local FlowSeparationMath =
	require(ServerScriptService.Contexts.Combat.Infrastructure.Services.MovementService.Math.FlowSeparationMath)

local function _HasCoreSharedMemoryFields(memory: SharedTable): boolean
	return memory.GoalGroupCellRecordStartIndex ~= nil
		and memory.GoalGroupCellRecordCount ~= nil
		and memory.GoalGroupCellWidthStuds ~= nil
		and memory.GroupCellX ~= nil
		and memory.GroupCellY ~= nil
		and memory.CellPackedKey ~= nil
		and memory.CellMemberStartIndex ~= nil
		and memory.CellMemberCount ~= nil
		and memory.CellMemberEntityIndex ~= nil
		and memory.FlatPositionX ~= nil
		and memory.FlatPositionY ~= nil
		and memory.Radius ~= nil
		and memory.FlowVelocityX ~= nil
		and memory.FlowVelocityY ~= nil
		and memory.PreviousVelocityX ~= nil
		and memory.PreviousVelocityY ~= nil
		and memory.WalkSpeed ~= nil
		and memory.VelAlpha ~= nil
		and memory.IsSettled ~= nil
		and memory.WallPackedKeys ~= nil
end

local Worker = {}

function Worker.Execute(request)
	local memory = request.SharedMemory
	if memory == nil then
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
			DeltaTime = if type(memory.DeltaTime) == "number" then memory.DeltaTime else 0,
			CellWidthStuds = if type(memory.CellWidthStuds) == "number" then memory.CellWidthStuds else 1,
			OriginX = if type(memory.OriginX) == "number" then memory.OriginX else 0,
			OriginY = if type(memory.OriginY) == "number" then memory.OriginY else 0,
			WallGridHalfSize = if type(memory.WallGridHalfSize) == "number" then memory.WallGridHalfSize else nil,
			KForce = if type(memory.KForce) == "number" then memory.KForce else 80,
			MinSeparationDistance = if type(memory.MinSeparationDistance) == "number"
				then memory.MinSeparationDistance
				else 1e-4,
			WallCollisionEnabled = memory.WallCollisionEnabled == true,
			WallCollisionAxisClampEnabled = memory.WallCollisionAxisClampEnabled == true,
			WallCollisionCornerClampEnabled = memory.WallCollisionCornerClampEnabled == true,
			WallCollisionUseUnitRadiusPadding = memory.WallCollisionUseUnitRadiusPadding == true,
			WallCollisionCellProbePaddingStuds = if type(memory.WallCollisionCellProbePaddingStuds) == "number"
				then memory.WallCollisionCellProbePaddingStuds
				else 0,
			WallCollisionVelocityEpsilon = if type(memory.WallCollisionVelocityEpsilon) == "number"
				then memory.WallCollisionVelocityEpsilon
				else 1e-4,
			ClumpTouchPaddingStuds = if type(memory.ClumpTouchPaddingStuds) == "number"
				then memory.ClumpTouchPaddingStuds
				else 0,
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
