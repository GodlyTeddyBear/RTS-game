--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local ParallelQuery = require(ReplicatedStorage.Utilities.ParallelQuery)
local FlowSeparationPairMath =
	require(ServerScriptService.Contexts.Combat.Infrastructure.Services.MovementService.FlowSeparationPairMath)

local OPERATION_NAME = "FlowSeparationPair"

local FlowSeparationPairOperation
FlowSeparationPairOperation = ParallelQuery.Operation.DefineCached({
	Name = OPERATION_NAME,
	ResultSchema = {
		ParallelQuery.Field.u32("EntityIndexA"),
		ParallelQuery.Field.u32("EntityIndexB"),
		ParallelQuery.Field.f32("DeltaAX"),
		ParallelQuery.Field.f32("DeltaAY"),
		ParallelQuery.Field.f32("DeltaBX"),
		ParallelQuery.Field.f32("DeltaBY"),
	},
	Execute = function(taskId: number, memory: SharedTable?)
		local emptyRow = FlowSeparationPairOperation:BuildEmptyRow()
		if memory == nil then
			return emptyRow
		end

		local pairA = memory.PairA
		local pairB = memory.PairB
		local positionX = memory.PositionX
		local positionY = memory.PositionY
		local radius = memory.Radius
		if pairA == nil or pairB == nil or positionX == nil or positionY == nil or radius == nil then
			return emptyRow
		end

		local entityIndexA = pairA[taskId]
		local entityIndexB = pairB[taskId]
		if type(entityIndexA) ~= "number" or type(entityIndexB) ~= "number" then
			return emptyRow
		end

		local ax = positionX[entityIndexA]
		local ay = positionY[entityIndexA]
		local bx = positionX[entityIndexB]
		local by = positionY[entityIndexB]
		local radiusA = radius[entityIndexA]
		local radiusB = radius[entityIndexB]
		if type(ax) ~= "number" or type(ay) ~= "number" or type(bx) ~= "number" or type(by) ~= "number" then
			return emptyRow
		end
		if type(radiusA) ~= "number" or type(radiusB) ~= "number" then
			return emptyRow
		end

		local minSeparationDistance = if type(memory.MinSeparationDistance) == "number"
			then memory.MinSeparationDistance
			else 1e-4
		local deltaX, deltaY, shouldApply = FlowSeparationPairMath.ComputePairDelta(
			ax,
			ay,
			bx,
			by,
			radiusA,
			radiusB,
			if type(memory.KForce) == "number" then memory.KForce else 80,
			minSeparationDistance
		)
		if not shouldApply then
			return FlowSeparationPairOperation:BuildEmptyRow({
				EntityIndexA = entityIndexA,
				EntityIndexB = entityIndexB,
			})
		end

		return {
			EntityIndexA = entityIndexA,
			EntityIndexB = entityIndexB,
			DeltaAX = deltaX,
			DeltaAY = deltaY,
			DeltaBX = -deltaX,
			DeltaBY = -deltaY,
		}
	end,
})

return FlowSeparationPairOperation
