--!strict
--!optimize 2
--!native

local MovementMath = require(script.Parent.MovementMath)

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

local function _FindLookupCellRecordIndex(
	lookupPackedKeyArray: { number },
	lookupCellRecordIndexArray: { number },
	startIndex: number,
	count: number,
	value: number
): number?
	local endIndex = startIndex + count - 1
	for lookupIndex = startIndex, endIndex do
		if lookupPackedKeyArray[lookupIndex] == value then
			local cellRecordIndex = lookupCellRecordIndexArray[lookupIndex]
			if type(cellRecordIndex) == "number" then
				return cellRecordIndex
			end
			return nil
		end
	end
	return nil
end

local function _AccumulateNeighborCell(
	entityIndex: number,
	lookupPackedKeyArray: { number },
	lookupCellRecordIndexArray: { number },
	goalGroupCellLookupStartIndex: number,
	goalGroupCellLookupCount: number,
	neighborCellPackedKey: number,
	cellMemberStartIndexArray: { number },
	cellMemberCountArray: { number },
	cellMemberEntityIndexArray: { number },
	flatPositionX: number,
	flatPositionY: number,
	radius: number,
	flatPositionXArray: { number },
	flatPositionYArray: { number },
	radiusArray: { number },
	isSettled: boolean,
	isSettledArray: { boolean },
	clumpTouchPaddingStuds: number,
	kForce: number,
	minSeparationDistance: number,
	separationX: number,
	separationY: number,
	touchedSettledNeighbor: boolean
): (number, number, boolean)
	local cellRecordIndex = _FindLookupCellRecordIndex(
		lookupPackedKeyArray,
		lookupCellRecordIndexArray,
		goalGroupCellLookupStartIndex,
		goalGroupCellLookupCount,
		neighborCellPackedKey
	)
	if not cellRecordIndex then
		return separationX, separationY, touchedSettledNeighbor
	end

	local memberStartIndex = cellMemberStartIndexArray[cellRecordIndex]
	local memberCount = cellMemberCountArray[cellRecordIndex]
	if type(memberStartIndex) ~= "number" or type(memberCount) ~= "number" then
		return separationX, separationY, touchedSettledNeighbor
	end

	local memberEndIndex = memberStartIndex + memberCount - 1
	for memberIndex = memberStartIndex, memberEndIndex do
		local otherEntityIndex = cellMemberEntityIndexArray[memberIndex]
		if type(otherEntityIndex) == "number" and otherEntityIndex ~= entityIndex then
			local otherFlatPositionX = flatPositionXArray[otherEntityIndex]
			local otherFlatPositionY = flatPositionYArray[otherEntityIndex]
			local otherRadius = radiusArray[otherEntityIndex]
			if
				type(otherFlatPositionX) == "number"
				and type(otherFlatPositionY) == "number"
				and type(otherRadius) == "number"
			then
				local deltaX, deltaY, shouldApply = FlowSeparationMath.ComputePairDelta(
					flatPositionX,
					flatPositionY,
					otherFlatPositionX,
					otherFlatPositionY,
					radius,
					otherRadius,
					kForce,
					minSeparationDistance
				)
				if shouldApply then
					separationX += deltaX
					separationY += deltaY
				end

				if not touchedSettledNeighbor and not isSettled and isSettledArray[otherEntityIndex] then
					local touchDistance = radius + otherRadius + clumpTouchPaddingStuds
					local touchDistanceSq = touchDistance * touchDistance
					local flatDeltaX = flatPositionX - otherFlatPositionX
					local flatDeltaY = flatPositionY - otherFlatPositionY
					local distanceSq = flatDeltaX * flatDeltaX + flatDeltaY * flatDeltaY
					if distanceSq <= touchDistanceSq then
						touchedSettledNeighbor = true
					end
				end
			end
		end
	end

	return separationX, separationY, touchedSettledNeighbor
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
	wallGrid: { boolean },
	wallGridHalfSize: number,
	wallGridWidth: number,
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
	local index = MovementMath.WallGridIndex(gx, gy, wallGridHalfSize, wallGridWidth)
	return wallGrid[index] == true, gx, gy
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
	local distanceSq = dx * dx + dy * dy
	local radiusSum = radiusA + radiusB
	if distanceSq >= radiusSum * radiusSum or distanceSq <= minSeparationDistance * minSeparationDistance then
		return 0, 0, false
	end

	local distance = math.sqrt(distanceSq)
	local penetration = radiusSum - distance
	local force = kForce * penetration * penetration / distance
	return dx * force, dy * force, true
end

function FlowSeparationMath.ResolveVelocityWithWalls(config: {
	EntityIndex: number,
	GoalGroupCellRecordStartIndex: { number },
	GoalGroupCellRecordCount: { number },
	GoalGroupCellLookupStartIndex: { number },
	GoalGroupCellLookupCount: { number },
	GoalGroupCellWidthStuds: { number },
	GroupCellX: { number },
	GroupCellY: { number },
	CellPackedKey: { number },
	CellMemberStartIndex: { number },
	CellMemberCount: { number },
	CellMemberEntityIndex: { number },
	LookupPackedKey: { number },
	LookupCellRecordIndex: { number },
	FlatPositionX: { number },
	FlatPositionY: { number },
	Radius: { number },
	FlowVelocityX: { number },
	FlowVelocityY: { number },
	PreviousVelocityX: { number },
	PreviousVelocityY: { number },
	WalkSpeed: { number },
	VelAlpha: { number },
	IsSettled: { boolean },
	WallGrid: { boolean },
	DeltaTime: number,
	CellWidthStuds: number,
	OriginX: number,
	OriginY: number,
	WallGridHalfSize: number?,
	WallGridWidth: number?,
	KForce: number,
	MinSeparationDistance: number,
	WallCollisionEnabled: boolean,
	WallCollisionAxisClampEnabled: boolean,
	WallCollisionCornerClampEnabled: boolean,
	WallCollisionUseUnitRadiusPadding: boolean,
	WallCollisionCellProbePaddingStuds: number,
	WallCollisionVelocityEpsilon: number,
	ClumpTouchPaddingStuds: number,
}): (Vector2, boolean)
	local entityIndex = config.EntityIndex
	local goalGroupCellLookupStartIndex = config.GoalGroupCellLookupStartIndex[entityIndex]
	local goalGroupCellLookupCount = config.GoalGroupCellLookupCount[entityIndex]
	local groupCellX = config.GroupCellX[entityIndex]
	local groupCellY = config.GroupCellY[entityIndex]
	local walkSpeed = config.WalkSpeed[entityIndex]
	local velAlpha = config.VelAlpha[entityIndex]
	local flowVelocityX = config.FlowVelocityX[entityIndex]
	local flowVelocityY = config.FlowVelocityY[entityIndex]
	local previousVelocityX = config.PreviousVelocityX[entityIndex]
	local previousVelocityY = config.PreviousVelocityY[entityIndex]
	local flatPositionX = config.FlatPositionX[entityIndex]
	local flatPositionY = config.FlatPositionY[entityIndex]
	local radius = config.Radius[entityIndex]
	local isSettled = config.IsSettled[entityIndex] == true
	local cellMemberStartIndexArray = config.CellMemberStartIndex
	local cellMemberCountArray = config.CellMemberCount
	local cellMemberEntityIndexArray = config.CellMemberEntityIndex
	local lookupPackedKeyArray = config.LookupPackedKey
	local lookupCellRecordIndexArray = config.LookupCellRecordIndex
	local flatPositionXArray = config.FlatPositionX
	local flatPositionYArray = config.FlatPositionY
	local radiusArray = config.Radius
	local isSettledArray = config.IsSettled
	local kForce = config.KForce
	local minSeparationDistance = config.MinSeparationDistance
	local clumpTouchPaddingStuds = config.ClumpTouchPaddingStuds
	local wallCollisionEnabled = config.WallCollisionEnabled
	local wallCollisionVelocityEpsilon = config.WallCollisionVelocityEpsilon
	local wallCollisionUseUnitRadiusPadding = config.WallCollisionUseUnitRadiusPadding
	local wallCollisionCellProbePaddingStuds = config.WallCollisionCellProbePaddingStuds
	local wallCollisionAxisClampEnabled = config.WallCollisionAxisClampEnabled
	local wallCollisionCornerClampEnabled = config.WallCollisionCornerClampEnabled
	local deltaTime = config.DeltaTime
	local originX = config.OriginX
	local originY = config.OriginY
	local cellWidthStuds = config.CellWidthStuds
	local wallGrid = config.WallGrid
	local wallGridHalfSize = config.WallGridHalfSize
	local wallGridWidth = config.WallGridWidth

	if type(goalGroupCellLookupStartIndex) ~= "number" or type(goalGroupCellLookupCount) ~= "number" then
		return Vector2.zero, false
	end
	if type(groupCellX) ~= "number" or type(groupCellY) ~= "number" then
		return Vector2.zero, false
	end
	if type(walkSpeed) ~= "number" or type(velAlpha) ~= "number" then
		return Vector2.zero, false
	end
	if type(flowVelocityX) ~= "number" or type(flowVelocityY) ~= "number" then
		return Vector2.zero, false
	end
	if type(previousVelocityX) ~= "number" or type(previousVelocityY) ~= "number" then
		return Vector2.zero, false
	end
	if type(flatPositionX) ~= "number" or type(flatPositionY) ~= "number" or type(radius) ~= "number" then
		return Vector2.zero, false
	end
	if type(wallGridHalfSize) ~= "number" or type(wallGridWidth) ~= "number" then
		return Vector2.zero, false
	end

	local separationX = 0
	local separationY = 0
	local touchedSettledNeighbor = false
	local neighborCellPackedKey1 = MovementMath.PackedSeparationCellKey(groupCellX - 1, groupCellY - 1)
	local neighborCellPackedKey2 = MovementMath.PackedSeparationCellKey(groupCellX - 1, groupCellY)
	local neighborCellPackedKey3 = MovementMath.PackedSeparationCellKey(groupCellX - 1, groupCellY + 1)
	local neighborCellPackedKey4 = MovementMath.PackedSeparationCellKey(groupCellX, groupCellY - 1)
	local neighborCellPackedKey5 = MovementMath.PackedSeparationCellKey(groupCellX, groupCellY)
	local neighborCellPackedKey6 = MovementMath.PackedSeparationCellKey(groupCellX, groupCellY + 1)
	local neighborCellPackedKey7 = MovementMath.PackedSeparationCellKey(groupCellX + 1, groupCellY - 1)
	local neighborCellPackedKey8 = MovementMath.PackedSeparationCellKey(groupCellX + 1, groupCellY)
	local neighborCellPackedKey9 = MovementMath.PackedSeparationCellKey(groupCellX + 1, groupCellY + 1)

	for cellGroupIndex = 1, 7, 3 do
		if cellGroupIndex == 1 then
			separationX, separationY, touchedSettledNeighbor = _AccumulateNeighborCell(
				entityIndex,
				lookupPackedKeyArray,
				lookupCellRecordIndexArray,
				goalGroupCellLookupStartIndex,
				goalGroupCellLookupCount,
				neighborCellPackedKey1,
				cellMemberStartIndexArray,
				cellMemberCountArray,
				cellMemberEntityIndexArray,
				flatPositionX,
				flatPositionY,
				radius,
				flatPositionXArray,
				flatPositionYArray,
				radiusArray,
				isSettled,
				isSettledArray,
				clumpTouchPaddingStuds,
				kForce,
				minSeparationDistance,
				separationX,
				separationY,
				touchedSettledNeighbor
			)
			separationX, separationY, touchedSettledNeighbor = _AccumulateNeighborCell(entityIndex, lookupPackedKeyArray, lookupCellRecordIndexArray, goalGroupCellLookupStartIndex, goalGroupCellLookupCount, neighborCellPackedKey2, cellMemberStartIndexArray, cellMemberCountArray, cellMemberEntityIndexArray, flatPositionX, flatPositionY, radius, flatPositionXArray, flatPositionYArray, radiusArray, isSettled, isSettledArray, clumpTouchPaddingStuds, kForce, minSeparationDistance, separationX, separationY, touchedSettledNeighbor)
			separationX, separationY, touchedSettledNeighbor = _AccumulateNeighborCell(entityIndex, lookupPackedKeyArray, lookupCellRecordIndexArray, goalGroupCellLookupStartIndex, goalGroupCellLookupCount, neighborCellPackedKey3, cellMemberStartIndexArray, cellMemberCountArray, cellMemberEntityIndexArray, flatPositionX, flatPositionY, radius, flatPositionXArray, flatPositionYArray, radiusArray, isSettled, isSettledArray, clumpTouchPaddingStuds, kForce, minSeparationDistance, separationX, separationY, touchedSettledNeighbor)
		elseif cellGroupIndex == 4 then
			separationX, separationY, touchedSettledNeighbor = _AccumulateNeighborCell(entityIndex, lookupPackedKeyArray, lookupCellRecordIndexArray, goalGroupCellLookupStartIndex, goalGroupCellLookupCount, neighborCellPackedKey4, cellMemberStartIndexArray, cellMemberCountArray, cellMemberEntityIndexArray, flatPositionX, flatPositionY, radius, flatPositionXArray, flatPositionYArray, radiusArray, isSettled, isSettledArray, clumpTouchPaddingStuds, kForce, minSeparationDistance, separationX, separationY, touchedSettledNeighbor)
			separationX, separationY, touchedSettledNeighbor = _AccumulateNeighborCell(entityIndex, lookupPackedKeyArray, lookupCellRecordIndexArray, goalGroupCellLookupStartIndex, goalGroupCellLookupCount, neighborCellPackedKey5, cellMemberStartIndexArray, cellMemberCountArray, cellMemberEntityIndexArray, flatPositionX, flatPositionY, radius, flatPositionXArray, flatPositionYArray, radiusArray, isSettled, isSettledArray, clumpTouchPaddingStuds, kForce, minSeparationDistance, separationX, separationY, touchedSettledNeighbor)
			separationX, separationY, touchedSettledNeighbor = _AccumulateNeighborCell(entityIndex, lookupPackedKeyArray, lookupCellRecordIndexArray, goalGroupCellLookupStartIndex, goalGroupCellLookupCount, neighborCellPackedKey6, cellMemberStartIndexArray, cellMemberCountArray, cellMemberEntityIndexArray, flatPositionX, flatPositionY, radius, flatPositionXArray, flatPositionYArray, radiusArray, isSettled, isSettledArray, clumpTouchPaddingStuds, kForce, minSeparationDistance, separationX, separationY, touchedSettledNeighbor)
		else
			separationX, separationY, touchedSettledNeighbor = _AccumulateNeighborCell(entityIndex, lookupPackedKeyArray, lookupCellRecordIndexArray, goalGroupCellLookupStartIndex, goalGroupCellLookupCount, neighborCellPackedKey7, cellMemberStartIndexArray, cellMemberCountArray, cellMemberEntityIndexArray, flatPositionX, flatPositionY, radius, flatPositionXArray, flatPositionYArray, radiusArray, isSettled, isSettledArray, clumpTouchPaddingStuds, kForce, minSeparationDistance, separationX, separationY, touchedSettledNeighbor)
			separationX, separationY, touchedSettledNeighbor = _AccumulateNeighborCell(entityIndex, lookupPackedKeyArray, lookupCellRecordIndexArray, goalGroupCellLookupStartIndex, goalGroupCellLookupCount, neighborCellPackedKey8, cellMemberStartIndexArray, cellMemberCountArray, cellMemberEntityIndexArray, flatPositionX, flatPositionY, radius, flatPositionXArray, flatPositionYArray, radiusArray, isSettled, isSettledArray, clumpTouchPaddingStuds, kForce, minSeparationDistance, separationX, separationY, touchedSettledNeighbor)
			separationX, separationY, touchedSettledNeighbor = _AccumulateNeighborCell(entityIndex, lookupPackedKeyArray, lookupCellRecordIndexArray, goalGroupCellLookupStartIndex, goalGroupCellLookupCount, neighborCellPackedKey9, cellMemberStartIndexArray, cellMemberCountArray, cellMemberEntityIndexArray, flatPositionX, flatPositionY, radius, flatPositionXArray, flatPositionYArray, radiusArray, isSettled, isSettledArray, clumpTouchPaddingStuds, kForce, minSeparationDistance, separationX, separationY, touchedSettledNeighbor)
		end
	end

	local unclampedVelocityX = flowVelocityX + separationX
	local unclampedVelocityY = flowVelocityY + separationY
	local targetVelocityX = unclampedVelocityX
	local targetVelocityY = unclampedVelocityY
	local unclampedMagnitude =
		math.sqrt(unclampedVelocityX * unclampedVelocityX + unclampedVelocityY * unclampedVelocityY)
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

	if not wallCollisionEnabled then
		return Vector2.new(velocityX, velocityY), touchedSettledNeighbor
	end

	local velocityMagnitude = math.sqrt(velocityX * velocityX + velocityY * velocityY)
	if velocityMagnitude <= wallCollisionVelocityEpsilon then
		return Vector2.new(velocityX, velocityY), touchedSettledNeighbor
	end

	local padding = wallCollisionCellProbePaddingStuds
	if wallCollisionUseUnitRadiusPadding then
		padding += radius
	end
	if wallCollisionAxisClampEnabled then
		local blockedX = _ProbeWallCell(
			flatPositionX,
			flatPositionY,
			velocityX,
			0,
			deltaTime,
			originX,
			originY,
			cellWidthStuds,
			wallGrid,
			wallGridHalfSize,
			wallGridWidth,
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
			deltaTime,
			originX,
			originY,
			cellWidthStuds,
			wallGrid,
			wallGridHalfSize,
			wallGridWidth,
			padding
		)
		if blockedY then
			velocityY = 0
		end
	end

	if wallCollisionCornerClampEnabled then
		local blockedCombined, blockedGx, blockedGy = _ProbeWallCell(
			flatPositionX,
			flatPositionY,
			velocityX,
			velocityY,
			deltaTime,
			originX,
			originY,
			cellWidthStuds,
			wallGrid,
			wallGridHalfSize,
			wallGridWidth,
			padding
		)
		if blockedCombined then
			local cornerX, cornerY =
				_GridToWorldFlat(blockedGx, blockedGy, originX, originY, cellWidthStuds)
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

	return Vector2.new(velocityX, velocityY), touchedSettledNeighbor
end

return table.freeze(FlowSeparationMath)
