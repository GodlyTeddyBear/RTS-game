--!strict

local FlowSeparationMath = {}

local function _WorldFlatToGrid(
	x: number,
	y: number,
	originX: number,
	originY: number,
	cellWidthStuds: number
): (number, number)
	return math.round((x - originX) / cellWidthStuds), math.round((y - originY) / cellWidthStuds)
end

local function _GridToWorldFlat(
	gx: number,
	gy: number,
	originX: number,
	originY: number,
	cellWidthStuds: number
): (number, number)
	return originX + gx * cellWidthStuds, originY + gy * cellWidthStuds
end

local function _BinarySearchContains(sortedValues: { number }, value: number): boolean
	local low = 1
	local high = #sortedValues
	while low <= high do
		local mid = math.floor((low + high) * 0.5)
		local midValue = sortedValues[mid]
		if midValue == value then
			return true
		end
		if midValue < value then
			low = mid + 1
		else
			high = mid - 1
		end
	end
	return false
end

local function _ProbeWallCell(
	flatPositionX: number,
	flatPositionY: number,
	velocityX: number,
	velocityY: number,
	dt: number,
	originX: number,
	originY: number,
	cellWidthStuds: number,
	wallPackedKeys: { number },
	radiusPaddingStuds: number
): (boolean, number, number)
	local probeX = flatPositionX + velocityX * dt
	local probeY = flatPositionY + velocityY * dt

	if radiusPaddingStuds > 0 then
		local magnitude = math.sqrt(velocityX * velocityX + velocityY * velocityY)
		if magnitude > 0 then
			local scale = radiusPaddingStuds / magnitude
			probeX += velocityX * scale
			probeY += velocityY * scale
		end
	end

	local gx, gy = _WorldFlatToGrid(probeX, probeY, originX, originY, cellWidthStuds)
	local key = (gx + 0x8000) * 0x10000 + (gy + 0x8000)
	return _BinarySearchContains(wallPackedKeys, key), gx, gy
end

function FlowSeparationMath.ComputePairDelta(
	ax: number,
	ay: number,
	bx: number,
	by: number,
	radiusA: number,
	radiusB: number,
	kForce: number,
	minSeparationDistance: number
): (number, number, boolean)
	local dx = ax - bx
	local dy = ay - by
	local distance = math.sqrt(dx * dx + dy * dy)
	local penetration = radiusA + radiusB - distance
	if penetration <= 0 or distance <= minSeparationDistance then
		return 0, 0, false
	end

	local force = kForce * penetration * penetration / distance
	return dx * force, dy * force, true
end

function FlowSeparationMath.AccumulatePairDelta(
	accumulator: { [number]: Vector2 },
	entityA: number,
	entityB: number,
	deltaAX: number,
	deltaAY: number,
	deltaBX: number,
	deltaBY: number
)
	accumulator[entityA] = (accumulator[entityA] or Vector2.zero) + Vector2.new(deltaAX, deltaAY)
	accumulator[entityB] = (accumulator[entityB] or Vector2.zero) + Vector2.new(deltaBX, deltaBY)
end

function FlowSeparationMath.ComputeSeparationForEntity(
	entityIndex: number,
	goalGroupIds: { number },
	flatPositionX: { number },
	flatPositionY: { number },
	radius: { number },
	kForce: number,
	minSeparationDistance: number
): Vector2
	local ownGroupId = goalGroupIds[entityIndex]
	local ownX = flatPositionX[entityIndex]
	local ownY = flatPositionY[entityIndex]
	local ownRadius = radius[entityIndex]
	if type(ownGroupId) ~= "number" or type(ownX) ~= "number" or type(ownY) ~= "number" or type(ownRadius) ~= "number" then
		return Vector2.zero
	end

	local separation = Vector2.zero
	for otherIndex = 1, #goalGroupIds do
		if otherIndex ~= entityIndex and goalGroupIds[otherIndex] == ownGroupId then
			local otherX = flatPositionX[otherIndex]
			local otherY = flatPositionY[otherIndex]
			local otherRadius = radius[otherIndex]
			if type(otherX) == "number" and type(otherY) == "number" and type(otherRadius) == "number" then
				local deltaX, deltaY, shouldApply = FlowSeparationMath.ComputePairDelta(
					ownX,
					ownY,
					otherX,
					otherY,
					ownRadius,
					otherRadius,
					kForce,
					minSeparationDistance
				)
				if shouldApply then
					separation += Vector2.new(deltaX, deltaY)
				end
			end
		end
	end

	return separation
end

function FlowSeparationMath.ResolveVelocityWithWalls(config: {
	EntityIndex: number,
	GoalGroupId: { number },
	FlatPositionX: { number },
	FlatPositionY: { number },
	Radius: { number },
	FlowVelocityX: { number },
	FlowVelocityY: { number },
	PreviousVelocityX: { number },
	PreviousVelocityY: { number },
	WalkSpeed: { number },
	VelAlpha: { number },
	WallPackedKeys: { number },
	DeltaTime: number,
	CellWidthStuds: number,
	OriginX: number,
	OriginY: number,
	WallGridHalfSize: number?,
	KForce: number,
	MinSeparationDistance: number,
	WallCollisionEnabled: boolean,
	WallCollisionAxisClampEnabled: boolean,
	WallCollisionCornerClampEnabled: boolean,
	WallCollisionUseUnitRadiusPadding: boolean,
	WallCollisionCellProbePaddingStuds: number,
	WallCollisionVelocityEpsilon: number,
}): Vector2
	local entityIndex = config.EntityIndex
	local walkSpeed = config.WalkSpeed[entityIndex]
	local velAlpha = config.VelAlpha[entityIndex]
	local flowVelocityX = config.FlowVelocityX[entityIndex]
	local flowVelocityY = config.FlowVelocityY[entityIndex]
	local previousVelocityX = config.PreviousVelocityX[entityIndex]
	local previousVelocityY = config.PreviousVelocityY[entityIndex]
	local flatPositionX = config.FlatPositionX[entityIndex]
	local flatPositionY = config.FlatPositionY[entityIndex]
	local radius = config.Radius[entityIndex]

	if type(walkSpeed) ~= "number" or type(velAlpha) ~= "number" then
		return Vector2.zero
	end
	if type(flowVelocityX) ~= "number" or type(flowVelocityY) ~= "number" then
		return Vector2.zero
	end
	if type(previousVelocityX) ~= "number" or type(previousVelocityY) ~= "number" then
		return Vector2.zero
	end
	if type(flatPositionX) ~= "number" or type(flatPositionY) ~= "number" or type(radius) ~= "number" then
		return Vector2.zero
	end

	local separation = FlowSeparationMath.ComputeSeparationForEntity(
		entityIndex,
		config.GoalGroupId,
		config.FlatPositionX,
		config.FlatPositionY,
		config.Radius,
		config.KForce,
		config.MinSeparationDistance
	)
	local unclampedVelocityX = flowVelocityX + separation.X
	local unclampedVelocityY = flowVelocityY + separation.Y
	local targetVelocityX = unclampedVelocityX
	local targetVelocityY = unclampedVelocityY
	local unclampedMagnitude = math.sqrt(unclampedVelocityX * unclampedVelocityX + unclampedVelocityY * unclampedVelocityY)
	if walkSpeed <= 0 then
		targetVelocityX = 0
		targetVelocityY = 0
	elseif unclampedMagnitude > walkSpeed and unclampedMagnitude > 0 then
		local scale = walkSpeed / unclampedMagnitude
		targetVelocityX = unclampedVelocityX * scale
		targetVelocityY = unclampedVelocityY * scale
	end

	local velocityX = previousVelocityX * (1 - velAlpha) + targetVelocityX * velAlpha
	local velocityY = previousVelocityY * (1 - velAlpha) + targetVelocityY * velAlpha

	if not config.WallCollisionEnabled then
		return Vector2.new(velocityX, velocityY)
	end

	local velocityMagnitude = math.sqrt(velocityX * velocityX + velocityY * velocityY)
	if velocityMagnitude <= config.WallCollisionVelocityEpsilon then
		return Vector2.new(velocityX, velocityY)
	end

	local padding = config.WallCollisionCellProbePaddingStuds
	if config.WallCollisionUseUnitRadiusPadding then
		padding += radius
	end
	if config.WallCollisionAxisClampEnabled then
		local blockedX = _ProbeWallCell(
			flatPositionX,
			flatPositionY,
			velocityX,
			0,
			config.DeltaTime,
			config.OriginX,
			config.OriginY,
			config.CellWidthStuds,
			config.WallPackedKeys,
			padding
		)
		if blockedX then
			velocityX = 0
		end

		local blockedY = _ProbeWallCell(
			flatPositionX,
			flatPositionY,
			0,
			velocityY,
			config.DeltaTime,
			config.OriginX,
			config.OriginY,
			config.CellWidthStuds,
			config.WallPackedKeys,
			padding
		)
		if blockedY then
			velocityY = 0
		end
	end

	if config.WallCollisionCornerClampEnabled then
		local blockedCombined, blockedGx, blockedGy = _ProbeWallCell(
			flatPositionX,
			flatPositionY,
			velocityX,
			velocityY,
			config.DeltaTime,
			config.OriginX,
			config.OriginY,
			config.CellWidthStuds,
			config.WallPackedKeys,
			padding
		)
		if blockedCombined then
			local cornerX, cornerY = _GridToWorldFlat(
				blockedGx,
				blockedGy,
				config.OriginX,
				config.OriginY,
				config.CellWidthStuds
			)
			local cornerDisplacementX = cornerX - flatPositionX
			local cornerDisplacementY = cornerY - flatPositionY
			local leftRatio = math.abs(cornerDisplacementY / math.max(math.abs(cornerDisplacementX), 1e-6))
			local rightRatio = math.abs(velocityY / math.max(math.abs(velocityX), 1e-6))
			if leftRatio > rightRatio then
				velocityY = 0
			else
				velocityX = 0
			end
		end
	end

	return Vector2.new(velocityX, velocityY)
end

return table.freeze(FlowSeparationMath)
