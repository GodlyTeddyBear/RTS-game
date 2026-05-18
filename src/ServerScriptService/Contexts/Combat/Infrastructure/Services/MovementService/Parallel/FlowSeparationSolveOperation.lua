--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local ParallelQuery = require(ReplicatedStorage.Utilities.ParallelQuery)
local FlowSeparationMath =
	require(ServerScriptService.Contexts.Combat.Infrastructure.Services.MovementService.FlowSeparationMath)

local OPERATION_NAME = "FlowSeparationSolve"

local FlowSeparationSolveOperation
FlowSeparationSolveOperation = ParallelQuery.Operation.DefineCached({
	Name = OPERATION_NAME,
	ResultSchema = {
		ParallelQuery.Field.u32("EntityIndex"),
		ParallelQuery.Field.f32("VelocityX"),
		ParallelQuery.Field.f32("VelocityY"),
	},
	Execute = function(taskId: number, memory: SharedTable?)
		local emptyRow = FlowSeparationSolveOperation:BuildEmptyRow()
		if memory == nil then
			return emptyRow
		end

		local goalGroupId = memory.GoalGroupId
		local flatPositionX = memory.FlatPositionX
		local flatPositionY = memory.FlatPositionY
		local radius = memory.Radius
		local flowVelocityX = memory.FlowVelocityX
		local flowVelocityY = memory.FlowVelocityY
		local previousVelocityX = memory.PreviousVelocityX
		local previousVelocityY = memory.PreviousVelocityY
		local walkSpeed = memory.WalkSpeed
		local velAlpha = memory.VelAlpha
		local wallPackedKeys = memory.WallPackedKeys
		if goalGroupId == nil or flatPositionX == nil or flatPositionY == nil or radius == nil then
			return emptyRow
		end
		if flowVelocityX == nil or flowVelocityY == nil or previousVelocityX == nil or previousVelocityY == nil then
			return emptyRow
		end
		if walkSpeed == nil or velAlpha == nil or wallPackedKeys == nil then
			return emptyRow
		end
		if taskId < 1 or taskId > #goalGroupId then
			return emptyRow
		end

		local velocity = FlowSeparationMath.ResolveVelocityWithWalls({
			EntityIndex = taskId,
			GoalGroupId = goalGroupId,
			FlatPositionX = flatPositionX,
			FlatPositionY = flatPositionY,
			Radius = radius,
			FlowVelocityX = flowVelocityX,
			FlowVelocityY = flowVelocityY,
			PreviousVelocityX = previousVelocityX,
			PreviousVelocityY = previousVelocityY,
			WalkSpeed = walkSpeed,
			VelAlpha = velAlpha,
			WallPackedKeys = wallPackedKeys,
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
		})

		return {
			EntityIndex = taskId,
			VelocityX = velocity.X,
			VelocityY = velocity.Y,
		}
	end,
})

return FlowSeparationSolveOperation
