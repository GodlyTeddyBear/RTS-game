--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ParallelQuery = require(ReplicatedStorage.Utilities.ParallelQuery)

local OPERATION_NAME = "FlowVelocitySolve"
local MOVE_DIRECTION_EPSILON = 0.05

local FlowVelocitySolveOperation
FlowVelocitySolveOperation = ParallelQuery.Operation.DefineCached({
	Name = OPERATION_NAME,
	ResultSchema = {
		ParallelQuery.Field.u32("EntityIndex"),
		ParallelQuery.Field.f32("VelocityX"),
		ParallelQuery.Field.f32("VelocityY"),
		ParallelQuery.Field.boolean("ShouldMove"),
	},
	Execute = function(taskId: number, memory: SharedTable?)
		local emptyRow = FlowVelocitySolveOperation:BuildEmptyRow()
		if memory == nil then
			return emptyRow
		end

		local flowX = memory.FlowX
		local flowY = memory.FlowY
		local separationX = memory.SeparationX
		local separationY = memory.SeparationY
		local previousVelocityX = memory.PreviousVelocityX
		local previousVelocityY = memory.PreviousVelocityY
		local walkSpeed = memory.WalkSpeed
		local velAlpha = memory.VelAlpha
		if flowX == nil or flowY == nil or separationX == nil or separationY == nil then
			return emptyRow
		end
		if previousVelocityX == nil or previousVelocityY == nil or walkSpeed == nil or velAlpha == nil then
			return emptyRow
		end

		local resolvedWalkSpeed = walkSpeed[taskId]
		local resolvedVelAlpha = velAlpha[taskId]
		local resolvedFlowX = flowX[taskId]
		local resolvedFlowY = flowY[taskId]
		local resolvedSeparationX = separationX[taskId]
		local resolvedSeparationY = separationY[taskId]
		local resolvedPreviousVelocityX = previousVelocityX[taskId]
		local resolvedPreviousVelocityY = previousVelocityY[taskId]
		if type(resolvedWalkSpeed) ~= "number" or type(resolvedVelAlpha) ~= "number" then
			return emptyRow
		end
		if type(resolvedFlowX) ~= "number" or type(resolvedFlowY) ~= "number" then
			return emptyRow
		end
		if type(resolvedSeparationX) ~= "number" or type(resolvedSeparationY) ~= "number" then
			return emptyRow
		end
		if type(resolvedPreviousVelocityX) ~= "number" or type(resolvedPreviousVelocityY) ~= "number" then
			return emptyRow
		end

		local targetVelocityX, targetVelocityY
		if resolvedWalkSpeed <= 0 then
			targetVelocityX, targetVelocityY = 0, 0
		else
			local unclampedVelocityX = resolvedFlowX + resolvedSeparationX
			local unclampedVelocityY = resolvedFlowY + resolvedSeparationY
			local magnitude =
				math.sqrt(unclampedVelocityX * unclampedVelocityX + unclampedVelocityY * unclampedVelocityY)
			if magnitude > resolvedWalkSpeed and magnitude > 0 then
				local scale = resolvedWalkSpeed / magnitude
				targetVelocityX = unclampedVelocityX * scale
				targetVelocityY = unclampedVelocityY * scale
			else
				targetVelocityX = unclampedVelocityX
				targetVelocityY = unclampedVelocityY
			end
		end

		local velocityX = resolvedPreviousVelocityX * (1 - resolvedVelAlpha) + targetVelocityX * resolvedVelAlpha
		local velocityY = resolvedPreviousVelocityY * (1 - resolvedVelAlpha) + targetVelocityY * resolvedVelAlpha
		local shouldMove = math.sqrt(velocityX * velocityX + velocityY * velocityY) > MOVE_DIRECTION_EPSILON

		return {
			EntityIndex = taskId,
			VelocityX = velocityX,
			VelocityY = velocityY,
			ShouldMove = shouldMove,
		}
	end,
})

return FlowVelocitySolveOperation
