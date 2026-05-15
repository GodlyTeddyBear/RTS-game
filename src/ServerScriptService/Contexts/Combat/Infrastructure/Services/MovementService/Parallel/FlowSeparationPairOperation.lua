--!strict

local ServerScriptService = game:GetService("ServerScriptService")

local FlowSeparationPairMath = require(
	ServerScriptService.Contexts.Combat.Infrastructure.Services.MovementService.FlowSeparationPairMath
)

local OPERATION_NAME = "FlowSeparationPair"

local FlowSeparationPairOperation = {
	Name = OPERATION_NAME,
	CacheLocalMemory = true,
	ResultSchema = {
		{ Name = "EntityIndexA", Type = "u32" },
		{ Name = "EntityIndexB", Type = "u32" },
		{ Name = "DeltaAX", Type = "f32" },
		{ Name = "DeltaAY", Type = "f32" },
		{ Name = "DeltaBX", Type = "f32" },
		{ Name = "DeltaBY", Type = "f32" },
	},
}

local function _EmptyRow()
	return {
		EntityIndexA = 0,
		EntityIndexB = 0,
		DeltaAX = 0,
		DeltaAY = 0,
		DeltaBX = 0,
		DeltaBY = 0,
	}
end

function FlowSeparationPairOperation.Execute(taskId: number, memory: SharedTable?)
	if memory == nil then
		return _EmptyRow()
	end

	local pairA = memory.PairA
	local pairB = memory.PairB
	local positionX = memory.PositionX
	local positionY = memory.PositionY
	local radius = memory.Radius
	if pairA == nil or pairB == nil or positionX == nil or positionY == nil or radius == nil then
		return _EmptyRow()
	end

	local entityIndexA = pairA[taskId]
	local entityIndexB = pairB[taskId]
	if type(entityIndexA) ~= "number" or type(entityIndexB) ~= "number" then
		return _EmptyRow()
	end

	local ax = positionX[entityIndexA]
	local ay = positionY[entityIndexA]
	local bx = positionX[entityIndexB]
	local by = positionY[entityIndexB]
	local radiusA = radius[entityIndexA]
	local radiusB = radius[entityIndexB]
	if type(ax) ~= "number" or type(ay) ~= "number" or type(bx) ~= "number" or type(by) ~= "number" then
		return _EmptyRow()
	end
	if type(radiusA) ~= "number" or type(radiusB) ~= "number" then
		return _EmptyRow()
	end

	local minSeparationDistance = if type(memory.MinSeparationDistance) == "number" then memory.MinSeparationDistance else 1e-4
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
		return {
			EntityIndexA = entityIndexA,
			EntityIndexB = entityIndexB,
			DeltaAX = 0,
			DeltaAY = 0,
			DeltaBX = 0,
			DeltaBY = 0,
		}
	end

	return {
		EntityIndexA = entityIndexA,
		EntityIndexB = entityIndexB,
		DeltaAX = deltaX,
		DeltaAY = deltaY,
		DeltaBX = -deltaX,
		DeltaBY = -deltaY,
	}
end

return table.freeze(FlowSeparationPairOperation)
