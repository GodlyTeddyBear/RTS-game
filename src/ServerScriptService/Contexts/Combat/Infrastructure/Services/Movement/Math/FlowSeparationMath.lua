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

local function _FindHashedCellRecordIndex(
	cellHashPackedKeyArray: { number },
	cellHashRecordIndexArray: { number },
	startIndex: number,
	slotCount: number,
	packedKey: number
): number?
	if slotCount <= 0 then
		return nil
	end

	local slotMask = slotCount - 1
	local slotOffset = bit32.band(packedKey, slotMask)

	for _ = 1, slotCount do
		local hashIndex = startIndex + slotOffset
		local cellRecordIndex = cellHashRecordIndexArray[hashIndex]
		if cellRecordIndex == 0 then
			return nil
		end
		if cellHashPackedKeyArray[hashIndex] == packedKey and type(cellRecordIndex) == "number" then
			return cellRecordIndex
		end

		slotOffset = bit32.band(slotOffset + 1, slotMask)
	end

	return nil
end

local function _UpdateTouchedSettledNeighborForCell(
	entityIndex: number,
	memberStartIndex: number,
	memberCount: number,
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
	touchedSettledNeighbor: boolean
): boolean
	if touchedSettledNeighbor or isSettled then
		return touchedSettledNeighbor
	end

	local memberEndIndex = memberStartIndex + memberCount - 1
	for memberIndex = memberStartIndex, memberEndIndex do
		local otherEntityIndex = cellMemberEntityIndexArray[memberIndex]
		if type(otherEntityIndex) == "number" and otherEntityIndex ~= entityIndex then
			if not isSettledArray[otherEntityIndex] then
				continue
			end

			local otherFlatPositionX = flatPositionXArray[otherEntityIndex]
			local otherFlatPositionY = flatPositionYArray[otherEntityIndex]
			local otherRadius = radiusArray[otherEntityIndex]
			if
				type(otherFlatPositionX) == "number"
				and type(otherFlatPositionY) == "number"
				and type(otherRadius) == "number"
			then
				local touchDistance = radius + otherRadius + clumpTouchPaddingStuds
				local touchDistanceSq = touchDistance * touchDistance
				local flatDeltaX = flatPositionX - otherFlatPositionX
				local flatDeltaY = flatPositionY - otherFlatPositionY
				local distanceSq = flatDeltaX * flatDeltaX + flatDeltaY * flatDeltaY
				if distanceSq <= touchDistanceSq then
					return true
				end
			end
		end
	end

	return touchedSettledNeighbor
end

local function _AccumulatePairwiseNeighborCell(
	entityIndex: number,
	memberStartIndex: number,
	memberCount: number,
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
	local memberEndIndex = memberStartIndex + memberCount - 1
	for memberIndex = memberStartIndex, memberEndIndex do
		if memberEndIndex / memberIndex == 0.5 then
			task.wait()
		end

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
						--task.wait()
					end
				end
			end
		end
	end

	return separationX, separationY, touchedSettledNeighbor
end

local function _TryAccumulateAggregateNeighborCell(
	memberCount: number,
	flatPositionX: number,
	flatPositionY: number,
	groupCellWidthStuds: number,
	aggregateCellMinMembers: number,
	aggregateForceScale: number,
	aggregateInfluenceRadiusMultiplier: number,
	kForce: number,
	minSeparationDistance: number,
	cellAggregatePositionSumXArray: { number },
	cellAggregatePositionSumYArray: { number },
	cellRecordIndex: number,
	isOwnCell: boolean,
	separationX: number,
	separationY: number
): (number, number, boolean)
	if memberCount < aggregateCellMinMembers then
		return separationX, separationY, false
	end

	local positionSumX = cellAggregatePositionSumXArray[cellRecordIndex]
	local positionSumY = cellAggregatePositionSumYArray[cellRecordIndex]
	if type(positionSumX) ~= "number" or type(positionSumY) ~= "number" then
		return separationX, separationY, false
	end
	if type(groupCellWidthStuds) ~= "number" or groupCellWidthStuds <= 0 then
		return separationX, separationY, false
	end
	if type(aggregateForceScale) ~= "number" or type(aggregateInfluenceRadiusMultiplier) ~= "number" then
		return separationX, separationY, false
	end
	if aggregateInfluenceRadiusMultiplier <= 0 then
		return separationX, separationY, false
	end

	local centroidX
	local centroidY
	if isOwnCell then
		local remainingCount = memberCount - 1
		if remainingCount <= 0 then
			return separationX, separationY, false
		end

		centroidX = (positionSumX - flatPositionX) / remainingCount
		centroidY = (positionSumY - flatPositionY) / remainingCount
	else
		centroidX = positionSumX / memberCount
		centroidY = positionSumY / memberCount
	end

	local offsetX = flatPositionX - centroidX
	local offsetY = flatPositionY - centroidY
	local distanceSq = offsetX * offsetX + offsetY * offsetY
	if distanceSq <= minSeparationDistance * minSeparationDistance then
		if isOwnCell then
			return separationX, separationY, false
		end
		return separationX, separationY, true
	end

	local influenceRadius = groupCellWidthStuds * aggregateInfluenceRadiusMultiplier
	if influenceRadius <= minSeparationDistance then
		return separationX, separationY, false
	end

	local density = memberCount / (groupCellWidthStuds * groupCellWidthStuds)
	if density <= 0 then
		return separationX, separationY, false
	end

	local distance = math.sqrt(distanceSq)
	local falloff = math.max(0, 1 - distance / influenceRadius)
	if falloff <= 0 then
		return separationX, separationY, true
	end

	local inverseDistance = 1 / distance
	local force = kForce * aggregateForceScale * density * falloff * falloff
	separationX += offsetX * inverseDistance * force
	separationY += offsetY * inverseDistance * force
	return separationX, separationY, true
end

local function _AccumulateNeighborCell(
	entityIndex: number,
	cellHashPackedKeyArray: { number },
	cellHashRecordIndexArray: { number },
	goalGroupCellHashStartIndex: number,
	goalGroupCellHashSlotCount: number,
	neighborCellPackedKey: number,
	ownCellPackedKey: number,
	groupCellWidthStuds: number,
	cellMemberStartIndexArray: { number },
	cellMemberCountArray: { number },
	cellMemberEntityIndexArray: { number },
	cellAggregatePositionSumXArray: { number },
	cellAggregatePositionSumYArray: { number },
	cellHasSettledMemberArray: { boolean },
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
	aggregateCellMinMembers: number,
	aggregateForceScale: number,
	aggregateInfluenceRadiusMultiplier: number,
	separationX: number,
	separationY: number,
	touchedSettledNeighbor: boolean
): (number, number, boolean)
	local cellRecordIndex = _FindHashedCellRecordIndex(
		cellHashPackedKeyArray,
		cellHashRecordIndexArray,
		goalGroupCellHashStartIndex,
		goalGroupCellHashSlotCount,
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

	local isOwnCell = neighborCellPackedKey == ownCellPackedKey
	local didUseAggregate
	separationX, separationY, didUseAggregate = _TryAccumulateAggregateNeighborCell(
		memberCount,
		flatPositionX,
		flatPositionY,
		groupCellWidthStuds,
		aggregateCellMinMembers,
		aggregateForceScale,
		aggregateInfluenceRadiusMultiplier,
		kForce,
		minSeparationDistance,
		cellAggregatePositionSumXArray,
		cellAggregatePositionSumYArray,
		cellRecordIndex,
		isOwnCell,
		separationX,
		separationY
	)

	if didUseAggregate then
		local hasSettledMember = cellHasSettledMemberArray[cellRecordIndex]
		local shouldCheckSettledTouch = hasSettledMember ~= false
		if shouldCheckSettledTouch then
			touchedSettledNeighbor = _UpdateTouchedSettledNeighborForCell(
				entityIndex,
				memberStartIndex,
				memberCount,
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
				touchedSettledNeighbor
			)
		end

		return separationX, separationY, touchedSettledNeighbor
	end

	return _AccumulatePairwiseNeighborCell(
		entityIndex,
		memberStartIndex,
		memberCount,
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
	GoalGroupCellHashStartIndex: { number },
	GoalGroupCellHashSlotCount: { number },
	GoalGroupCellWidthStuds: { number },
	GroupCellX: { number },
	GroupCellY: { number },
	CellPackedKey: { number },
	CellMemberStartIndex: { number },
	CellMemberCount: { number },
	CellMemberEntityIndex: { number },
	CellHashPackedKey: { number },
	CellHashRecordIndex: { number },
	CellAggregatePositionSumX: { number },
	CellAggregatePositionSumY: { number },
	CellHasSettledMember: { boolean },
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
	AggregateCellMinMembers: number,
	AggregateForceScale: number,
	AggregateInfluenceRadiusMultiplier: number,
	WallCollisionEnabled: boolean,
	WallCollisionAxisClampEnabled: boolean,
	WallCollisionCornerClampEnabled: boolean,
	WallCollisionUseUnitRadiusPadding: boolean,
	WallCollisionCellProbePaddingStuds: number,
	WallCollisionVelocityEpsilon: number,
	ClumpTouchPaddingStuds: number,
}): (Vector2, boolean)
	local entityIndex = config.EntityIndex
	local goalGroupCellHashStartIndex = config.GoalGroupCellHashStartIndex[entityIndex]
	local goalGroupCellHashSlotCount = config.GoalGroupCellHashSlotCount[entityIndex]
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
	local cellHashPackedKeyArray = config.CellHashPackedKey
	local cellHashRecordIndexArray = config.CellHashRecordIndex
	local cellAggregatePositionSumXArray = config.CellAggregatePositionSumX
	local cellAggregatePositionSumYArray = config.CellAggregatePositionSumY
	local cellHasSettledMemberArray = config.CellHasSettledMember
	local flatPositionXArray = config.FlatPositionX
	local flatPositionYArray = config.FlatPositionY
	local radiusArray = config.Radius
	local isSettledArray = config.IsSettled
	local kForce = config.KForce
	local minSeparationDistance = config.MinSeparationDistance
	local aggregateCellMinMembers = config.AggregateCellMinMembers
	local aggregateForceScale = config.AggregateForceScale
	local aggregateInfluenceRadiusMultiplier = config.AggregateInfluenceRadiusMultiplier
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
	local groupCellWidthStuds = config.GoalGroupCellWidthStuds[entityIndex]

	if type(goalGroupCellHashStartIndex) ~= "number" or type(goalGroupCellHashSlotCount) ~= "number" then
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
	if type(groupCellWidthStuds) ~= "number" then
		return Vector2.zero, false
	end
	if type(wallGridHalfSize) ~= "number" or type(wallGridWidth) ~= "number" then
		return Vector2.zero, false
	end
	--task.wait()
	local separationX = 0
	local separationY = 0
	local touchedSettledNeighbor = false
	local ownCellPackedKey = MovementMath.PackedSeparationCellKey(groupCellX, groupCellY)
	local neighborCellPackedKey1 = MovementMath.PackedSeparationCellKey(groupCellX - 1, groupCellY - 1)
	local neighborCellPackedKey2 = MovementMath.PackedSeparationCellKey(groupCellX - 1, groupCellY)
	local neighborCellPackedKey3 = MovementMath.PackedSeparationCellKey(groupCellX - 1, groupCellY + 1)
	local neighborCellPackedKey4 = MovementMath.PackedSeparationCellKey(groupCellX, groupCellY - 1)
	local neighborCellPackedKey5 = ownCellPackedKey
	local neighborCellPackedKey6 = MovementMath.PackedSeparationCellKey(groupCellX, groupCellY + 1)
	local neighborCellPackedKey7 = MovementMath.PackedSeparationCellKey(groupCellX + 1, groupCellY - 1)
	local neighborCellPackedKey8 = MovementMath.PackedSeparationCellKey(groupCellX + 1, groupCellY)
	local neighborCellPackedKey9 = MovementMath.PackedSeparationCellKey(groupCellX + 1, groupCellY + 1)

	for cellGroupIndex = 1, 7, 3 do
		if cellGroupIndex == 1 then
			separationX, separationY, touchedSettledNeighbor = _AccumulateNeighborCell(
				entityIndex,
				cellHashPackedKeyArray,
				cellHashRecordIndexArray,
				goalGroupCellHashStartIndex,
				goalGroupCellHashSlotCount,
				neighborCellPackedKey1,
				ownCellPackedKey,
				groupCellWidthStuds,
				cellMemberStartIndexArray,
				cellMemberCountArray,
				cellMemberEntityIndexArray,
				cellAggregatePositionSumXArray,
				cellAggregatePositionSumYArray,
				cellHasSettledMemberArray,
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
				aggregateCellMinMembers,
				aggregateForceScale,
				aggregateInfluenceRadiusMultiplier,
				separationX,
				separationY,
				touchedSettledNeighbor
			)
			separationX, separationY, touchedSettledNeighbor = _AccumulateNeighborCell(
				entityIndex,
				cellHashPackedKeyArray,
				cellHashRecordIndexArray,
				goalGroupCellHashStartIndex,
				goalGroupCellHashSlotCount,
				neighborCellPackedKey2,
				ownCellPackedKey,
				groupCellWidthStuds,
				cellMemberStartIndexArray,
				cellMemberCountArray,
				cellMemberEntityIndexArray,
				cellAggregatePositionSumXArray,
				cellAggregatePositionSumYArray,
				cellHasSettledMemberArray,
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
				aggregateCellMinMembers,
				aggregateForceScale,
				aggregateInfluenceRadiusMultiplier,
				separationX,
				separationY,
				touchedSettledNeighbor
			)
			separationX, separationY, touchedSettledNeighbor = _AccumulateNeighborCell(
				entityIndex,
				cellHashPackedKeyArray,
				cellHashRecordIndexArray,
				goalGroupCellHashStartIndex,
				goalGroupCellHashSlotCount,
				neighborCellPackedKey3,
				ownCellPackedKey,
				groupCellWidthStuds,
				cellMemberStartIndexArray,
				cellMemberCountArray,
				cellMemberEntityIndexArray,
				cellAggregatePositionSumXArray,
				cellAggregatePositionSumYArray,
				cellHasSettledMemberArray,
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
				aggregateCellMinMembers,
				aggregateForceScale,
				aggregateInfluenceRadiusMultiplier,
				separationX,
				separationY,
				touchedSettledNeighbor
			)
		elseif cellGroupIndex == 4 then
			separationX, separationY, touchedSettledNeighbor = _AccumulateNeighborCell(
				entityIndex,
				cellHashPackedKeyArray,
				cellHashRecordIndexArray,
				goalGroupCellHashStartIndex,
				goalGroupCellHashSlotCount,
				neighborCellPackedKey4,
				ownCellPackedKey,
				groupCellWidthStuds,
				cellMemberStartIndexArray,
				cellMemberCountArray,
				cellMemberEntityIndexArray,
				cellAggregatePositionSumXArray,
				cellAggregatePositionSumYArray,
				cellHasSettledMemberArray,
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
				aggregateCellMinMembers,
				aggregateForceScale,
				aggregateInfluenceRadiusMultiplier,
				separationX,
				separationY,
				touchedSettledNeighbor
			)
			separationX, separationY, touchedSettledNeighbor = _AccumulateNeighborCell(
				entityIndex,
				cellHashPackedKeyArray,
				cellHashRecordIndexArray,
				goalGroupCellHashStartIndex,
				goalGroupCellHashSlotCount,
				neighborCellPackedKey5,
				ownCellPackedKey,
				groupCellWidthStuds,
				cellMemberStartIndexArray,
				cellMemberCountArray,
				cellMemberEntityIndexArray,
				cellAggregatePositionSumXArray,
				cellAggregatePositionSumYArray,
				cellHasSettledMemberArray,
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
				aggregateCellMinMembers,
				aggregateForceScale,
				aggregateInfluenceRadiusMultiplier,
				separationX,
				separationY,
				touchedSettledNeighbor
			)
			separationX, separationY, touchedSettledNeighbor = _AccumulateNeighborCell(
				entityIndex,
				cellHashPackedKeyArray,
				cellHashRecordIndexArray,
				goalGroupCellHashStartIndex,
				goalGroupCellHashSlotCount,
				neighborCellPackedKey6,
				ownCellPackedKey,
				groupCellWidthStuds,
				cellMemberStartIndexArray,
				cellMemberCountArray,
				cellMemberEntityIndexArray,
				cellAggregatePositionSumXArray,
				cellAggregatePositionSumYArray,
				cellHasSettledMemberArray,
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
				aggregateCellMinMembers,
				aggregateForceScale,
				aggregateInfluenceRadiusMultiplier,
				separationX,
				separationY,
				touchedSettledNeighbor
			)
		else
			separationX, separationY, touchedSettledNeighbor = _AccumulateNeighborCell(
				entityIndex,
				cellHashPackedKeyArray,
				cellHashRecordIndexArray,
				goalGroupCellHashStartIndex,
				goalGroupCellHashSlotCount,
				neighborCellPackedKey7,
				ownCellPackedKey,
				groupCellWidthStuds,
				cellMemberStartIndexArray,
				cellMemberCountArray,
				cellMemberEntityIndexArray,
				cellAggregatePositionSumXArray,
				cellAggregatePositionSumYArray,
				cellHasSettledMemberArray,
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
				aggregateCellMinMembers,
				aggregateForceScale,
				aggregateInfluenceRadiusMultiplier,
				separationX,
				separationY,
				touchedSettledNeighbor
			)
			separationX, separationY, touchedSettledNeighbor = _AccumulateNeighborCell(
				entityIndex,
				cellHashPackedKeyArray,
				cellHashRecordIndexArray,
				goalGroupCellHashStartIndex,
				goalGroupCellHashSlotCount,
				neighborCellPackedKey8,
				ownCellPackedKey,
				groupCellWidthStuds,
				cellMemberStartIndexArray,
				cellMemberCountArray,
				cellMemberEntityIndexArray,
				cellAggregatePositionSumXArray,
				cellAggregatePositionSumYArray,
				cellHasSettledMemberArray,
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
				aggregateCellMinMembers,
				aggregateForceScale,
				aggregateInfluenceRadiusMultiplier,
				separationX,
				separationY,
				touchedSettledNeighbor
			)
			separationX, separationY, touchedSettledNeighbor = _AccumulateNeighborCell(
				entityIndex,
				cellHashPackedKeyArray,
				cellHashRecordIndexArray,
				goalGroupCellHashStartIndex,
				goalGroupCellHashSlotCount,
				neighborCellPackedKey9,
				ownCellPackedKey,
				groupCellWidthStuds,
				cellMemberStartIndexArray,
				cellMemberCountArray,
				cellMemberEntityIndexArray,
				cellAggregatePositionSumXArray,
				cellAggregatePositionSumYArray,
				cellHasSettledMemberArray,
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
				aggregateCellMinMembers,
				aggregateForceScale,
				aggregateInfluenceRadiusMultiplier,
				separationX,
				separationY,
				touchedSettledNeighbor
			)
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
			local cornerX, cornerY = _GridToWorldFlat(blockedGx, blockedGy, originX, originY, cellWidthStuds)
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
