--!strict

local OPERATION_NAME = "FlowVelocitySolve"
local MOVE_DIRECTION_EPSILON = 0.05

local FlowVelocitySolveOperation = {
	Name = OPERATION_NAME,
	CacheLocalMemory = true,
	ResultSchema = {
		{ Name = "EntityIndex", Type = "u32" },
		{ Name = "VelocityX", Type = "f32" },
		{ Name = "VelocityY", Type = "f32" },
		{ Name = "ShouldMove", Type = "boolean" },
	},
}

local function _EmptyRow()
	return {
		EntityIndex = 0,
		VelocityX = 0,
		VelocityY = 0,
		ShouldMove = false,
	}
end

local function _ClampVector2Magnitude(x: number, y: number, maxMagnitude: number): (number, number)
	if maxMagnitude <= 0 then
		return 0, 0
	end

	local magnitude = math.sqrt(x * x + y * y)
	if magnitude > maxMagnitude and magnitude > 0 then
		local scale = maxMagnitude / magnitude
		return x * scale, y * scale
	end

	return x, y
end

function FlowVelocitySolveOperation.Execute(taskId: number, memory: SharedTable?)
	if memory == nil then
		return _EmptyRow()
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
		return _EmptyRow()
	end
	if previousVelocityX == nil or previousVelocityY == nil or walkSpeed == nil or velAlpha == nil then
		return _EmptyRow()
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
		return _EmptyRow()
	end
	if type(resolvedFlowX) ~= "number" or type(resolvedFlowY) ~= "number" then
		return _EmptyRow()
	end
	if type(resolvedSeparationX) ~= "number" or type(resolvedSeparationY) ~= "number" then
		return _EmptyRow()
	end
	if type(resolvedPreviousVelocityX) ~= "number" or type(resolvedPreviousVelocityY) ~= "number" then
		return _EmptyRow()
	end

	local targetVelocityX, targetVelocityY = _ClampVector2Magnitude(
		resolvedFlowX + resolvedSeparationX,
		resolvedFlowY + resolvedSeparationY,
		resolvedWalkSpeed
	)
	local velocityX = resolvedPreviousVelocityX * (1 - resolvedVelAlpha) + targetVelocityX * resolvedVelAlpha
	local velocityY = resolvedPreviousVelocityY * (1 - resolvedVelAlpha) + targetVelocityY * resolvedVelAlpha
	local shouldMove = math.sqrt(velocityX * velocityX + velocityY * velocityY) > MOVE_DIRECTION_EPSILON

	return {
		EntityIndex = taskId,
		VelocityX = velocityX,
		VelocityY = velocityY,
		ShouldMove = shouldMove,
	}
end

return table.freeze(FlowVelocitySolveOperation)
