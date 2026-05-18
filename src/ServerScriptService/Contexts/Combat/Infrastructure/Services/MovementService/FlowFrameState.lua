--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TableRecycler = require(ReplicatedStorage.Utilities.TableRecycler)
local FlowNeighborhoodMath = require(script.Parent.Math.FlowNeighborhoodMath)
local MovementMath = require(script.Parent.Math.MovementMath)
local MovementTypes = require(script.Parent.Types)

type TTableRecyclerHandle = TableRecycler.TTableRecyclerHandle
type TFlowFrameStateBuildSnapshotParams = MovementTypes.TFlowFrameStateBuildSnapshotParams
type TFlowFrameStateHandle = MovementTypes.TFlowFrameStateHandle
type TFlowSeparationSolveSnapshot = MovementTypes.TFlowSeparationSolveSnapshot

type TFlowFrameStateInternal = TFlowFrameStateHandle & {
	_destroyed: boolean,
	_recycler: TTableRecyclerHandle,
	_entityCount: number,
	_entityIds: { number },
	_goalGroupId: { number },
	_neighborStartIndex: { number },
	_neighborCount: { number },
	_neighborEntityIndex: { number },
	_flatPositionX: { number },
	_flatPositionY: { number },
	_radius: { number },
	_flowVelocityX: { number },
	_flowVelocityY: { number },
	_previousVelocityX: { number },
	_previousVelocityY: { number },
	_walkSpeed: { number },
	_velAlpha: { number },
	_isSettled: { boolean },
	_snapshot: TFlowSeparationSolveSnapshot,
	_defaultWallPackedKeys: { number },
	_touchedSettledNeighborByEntity: { [number]: boolean },
	_entityIndicesByGoalKey: { [string]: { number } },
	_activeGoalKeys: { string },
	_goalGroupIdByGoalKey: { [string]: number },
	_nextGoalGroupId: number,
	_scratchBucketsByCell: { [number]: { number } },
	_scratchCellKeys: { number },
	_scratchFreeCellBuckets: { { number } },
	_scratchGxByEntityIndex: { number },
	_scratchGzByEntityIndex: { number },
	_scratchSeenStampByEntityIndex: { number },
	_scratchNeighborStamp: number,
}

local FlowFrameState = {}
FlowFrameState.__index = FlowFrameState

local function _AcquireArray(recycler: TTableRecyclerHandle): { any }
	return recycler:AcquireArray()
end

local function _AcquireMap(recycler: TTableRecyclerHandle): { [any]: any }
	return recycler:AcquireMap()
end

local function _ReleaseTrackedArray(self: TFlowFrameStateInternal, tbl: { any })
	local didRelease, releaseError = self._recycler:ReleaseArray(tbl)
	assert(didRelease, releaseError)
end

local function _ReleaseTrackedMap(self: TFlowFrameStateInternal, tbl: { [any]: any })
	local didRelease, releaseError = self._recycler:ReleaseMap(tbl)
	assert(didRelease, releaseError)
end

local function _ResetScratchCellBuckets(self: TFlowFrameStateInternal)
	local scratchBucketsByCell = self._scratchBucketsByCell
	local scratchCellKeys = self._scratchCellKeys
	local scratchFreeCellBuckets = self._scratchFreeCellBuckets

	for _, cellKey in ipairs(scratchCellKeys) do
		local bucket = scratchBucketsByCell[cellKey]
		if bucket ~= nil then
			table.clear(bucket)
			scratchBucketsByCell[cellKey] = nil
			scratchFreeCellBuckets[#scratchFreeCellBuckets + 1] = bucket
		end
	end

	table.clear(scratchCellKeys)
end

local function _AcquireScratchCellBucket(self: TFlowFrameStateInternal): { number }
	local scratchFreeCellBuckets = self._scratchFreeCellBuckets
	local bucket = scratchFreeCellBuckets[#scratchFreeCellBuckets]
	if bucket ~= nil then
		scratchFreeCellBuckets[#scratchFreeCellBuckets] = nil
		return bucket
	end

	return _AcquireArray(self._recycler) :: { number }
end

local function _AppendGoalNeighborhoodData(
	self: TFlowFrameStateInternal,
	entityIndices: { number },
	clumpTouchPaddingStuds: number
)
	_ResetScratchCellBuckets(self)

	local cellWidthStuds = FlowNeighborhoodMath.ResolveCellWidthForEntityIndices(self, entityIndices)
	local scratchBucketsByCell = self._scratchBucketsByCell
	local scratchCellKeys = self._scratchCellKeys
	local scratchGxByEntityIndex = self._scratchGxByEntityIndex
	local scratchGzByEntityIndex = self._scratchGzByEntityIndex
	local neighborEntityIndex = self._neighborEntityIndex
	local neighborStartIndex = self._neighborStartIndex
	local neighborCount = self._neighborCount
	local touchedSettledNeighborByEntity = self._touchedSettledNeighborByEntity
	local seenStampByEntityIndex = self._scratchSeenStampByEntityIndex

	for _, entityIndex in ipairs(entityIndices) do
		local flatX = self._flatPositionX[entityIndex]
		local flatY = self._flatPositionY[entityIndex]
		local gx, gz = MovementMath.FlatPositionToCell(Vector2.new(flatX, flatY), cellWidthStuds)
		scratchGxByEntityIndex[entityIndex] = gx
		scratchGzByEntityIndex[entityIndex] = gz

		local cellKey = MovementMath.PackedSeparationCellKey(gx, gz)
		local bucket = scratchBucketsByCell[cellKey]
		if bucket == nil then
			bucket = _AcquireScratchCellBucket(self)
			scratchBucketsByCell[cellKey] = bucket
			scratchCellKeys[#scratchCellKeys + 1] = cellKey
		end

		bucket[#bucket + 1] = entityIndex
	end

	for _, entityIndex in ipairs(entityIndices) do
		local gx = scratchGxByEntityIndex[entityIndex]
		local gz = scratchGzByEntityIndex[entityIndex]
		local currentStamp = self._scratchNeighborStamp + 1
		self._scratchNeighborStamp = currentStamp

		local startIndex = #neighborEntityIndex + 1
		local entityIsSettled = self._isSettled[entityIndex] == true
		local entityRadius = self._radius[entityIndex] or 0
		local entityFlatX = self._flatPositionX[entityIndex] or 0
		local entityFlatY = self._flatPositionY[entityIndex] or 0

		for dx = -1, 1 do
			for dz = -1, 1 do
				local bucket = scratchBucketsByCell[MovementMath.PackedSeparationCellKey(gx + dx, gz + dz)]
				if bucket ~= nil then
					for _, otherEntityIndex in ipairs(bucket) do
						if
							otherEntityIndex ~= entityIndex
							and seenStampByEntityIndex[otherEntityIndex] ~= currentStamp
						then
							seenStampByEntityIndex[otherEntityIndex] = currentStamp
							neighborEntityIndex[#neighborEntityIndex + 1] = otherEntityIndex

							if entityIsSettled and self._isSettled[otherEntityIndex] ~= true then
								local otherRadius = self._radius[otherEntityIndex] or 0
								local touchDistance = entityRadius + otherRadius + clumpTouchPaddingStuds
								local flatDeltaX = entityFlatX - (self._flatPositionX[otherEntityIndex] or 0)
								local flatDeltaY = entityFlatY - (self._flatPositionY[otherEntityIndex] or 0)
								if math.sqrt(flatDeltaX * flatDeltaX + flatDeltaY * flatDeltaY) <= touchDistance then
									local otherEntity = self._entityIds[otherEntityIndex]
									if otherEntity ~= nil then
										touchedSettledNeighborByEntity[otherEntity] = true
									end
								end
							end
						end
					end
				end
			end
		end

		neighborStartIndex[entityIndex] = startIndex
		neighborCount[entityIndex] = #neighborEntityIndex - startIndex + 1
	end

	_ResetScratchCellBuckets(self)
end

function FlowFrameState.new(recycler: TTableRecyclerHandle): TFlowFrameStateHandle
	local entityIds = _AcquireArray(recycler) :: { number }
	local goalGroupId = _AcquireArray(recycler) :: { number }
	local neighborStartIndex = _AcquireArray(recycler) :: { number }
	local neighborCount = _AcquireArray(recycler) :: { number }
	local neighborEntityIndex = _AcquireArray(recycler) :: { number }
	local flatPositionX = _AcquireArray(recycler) :: { number }
	local flatPositionY = _AcquireArray(recycler) :: { number }
	local radius = _AcquireArray(recycler) :: { number }
	local flowVelocityX = _AcquireArray(recycler) :: { number }
	local flowVelocityY = _AcquireArray(recycler) :: { number }
	local previousVelocityX = _AcquireArray(recycler) :: { number }
	local previousVelocityY = _AcquireArray(recycler) :: { number }
	local walkSpeed = _AcquireArray(recycler) :: { number }
	local velAlpha = _AcquireArray(recycler) :: { number }
	local isSettled = _AcquireArray(recycler) :: { boolean }
	local defaultWallPackedKeys = _AcquireArray(recycler) :: { number }
	local touchedSettledNeighborByEntity = _AcquireMap(recycler) :: { [number]: boolean }
	local entityIndicesByGoalKey = _AcquireMap(recycler) :: { [string]: { number } }
	local activeGoalKeys = _AcquireArray(recycler) :: { string }
	local goalGroupIdByGoalKey = _AcquireMap(recycler) :: { [string]: number }
	local scratchBucketsByCell = _AcquireMap(recycler) :: { [number]: { number } }
	local scratchCellKeys = _AcquireArray(recycler) :: { number }
	local scratchFreeCellBuckets = _AcquireArray(recycler) :: { { number } }
	local scratchGxByEntityIndex = _AcquireArray(recycler) :: { number }
	local scratchGzByEntityIndex = _AcquireArray(recycler) :: { number }
	local scratchSeenStampByEntityIndex = _AcquireArray(recycler) :: { number }
	local snapshot = _AcquireMap(recycler) :: any

	snapshot.TickId = 0
	snapshot.EntityCount = 0
	snapshot.EntityIds = entityIds
	snapshot.GoalGroupId = goalGroupId
	snapshot.NeighborStartIndex = neighborStartIndex
	snapshot.NeighborCount = neighborCount
	snapshot.NeighborEntityIndex = neighborEntityIndex
	snapshot.FlatPositionX = flatPositionX
	snapshot.FlatPositionY = flatPositionY
	snapshot.Radius = radius
	snapshot.FlowVelocityX = flowVelocityX
	snapshot.FlowVelocityY = flowVelocityY
	snapshot.PreviousVelocityX = previousVelocityX
	snapshot.PreviousVelocityY = previousVelocityY
	snapshot.WalkSpeed = walkSpeed
	snapshot.VelAlpha = velAlpha
	snapshot.DeltaTime = 0
	snapshot.CellWidthStuds = 0
	snapshot.OriginX = 0
	snapshot.OriginY = 0
	snapshot.WallGridHalfSize = 0
	snapshot.WallPackedKeys = defaultWallPackedKeys
	snapshot.KForce = 0
	snapshot.MinSeparationDistance = 0
	snapshot.WallCollisionEnabled = false
	snapshot.WallCollisionAxisClampEnabled = false
	snapshot.WallCollisionCornerClampEnabled = false
	snapshot.WallCollisionUseUnitRadiusPadding = false
	snapshot.WallCollisionCellProbePaddingStuds = 0
	snapshot.WallCollisionVelocityEpsilon = 0

	local self = setmetatable({
		_destroyed = false,
		_recycler = recycler,
		_entityCount = 0,
		_entityIds = entityIds,
		_goalGroupId = goalGroupId,
		_neighborStartIndex = neighborStartIndex,
		_neighborCount = neighborCount,
		_neighborEntityIndex = neighborEntityIndex,
		_flatPositionX = flatPositionX,
		_flatPositionY = flatPositionY,
		_radius = radius,
		_flowVelocityX = flowVelocityX,
		_flowVelocityY = flowVelocityY,
		_previousVelocityX = previousVelocityX,
		_previousVelocityY = previousVelocityY,
		_walkSpeed = walkSpeed,
		_velAlpha = velAlpha,
		_isSettled = isSettled,
		_snapshot = snapshot :: TFlowSeparationSolveSnapshot,
		_defaultWallPackedKeys = defaultWallPackedKeys,
		_touchedSettledNeighborByEntity = touchedSettledNeighborByEntity,
		_entityIndicesByGoalKey = entityIndicesByGoalKey,
		_activeGoalKeys = activeGoalKeys,
		_goalGroupIdByGoalKey = goalGroupIdByGoalKey,
		_nextGoalGroupId = 0,
		_scratchBucketsByCell = scratchBucketsByCell,
		_scratchCellKeys = scratchCellKeys,
		_scratchFreeCellBuckets = scratchFreeCellBuckets,
		_scratchGxByEntityIndex = scratchGxByEntityIndex,
		_scratchGzByEntityIndex = scratchGzByEntityIndex,
		_scratchSeenStampByEntityIndex = scratchSeenStampByEntityIndex,
		_scratchNeighborStamp = 0,
	}, FlowFrameState)

	return self :: TFlowFrameStateHandle
end

function FlowFrameState:Reset()
	local selfInternal = self :: TFlowFrameStateInternal
	selfInternal._entityCount = 0
	selfInternal._nextGoalGroupId = 0

	table.clear(selfInternal._entityIds)
	table.clear(selfInternal._goalGroupId)
	table.clear(selfInternal._neighborStartIndex)
	table.clear(selfInternal._neighborCount)
	table.clear(selfInternal._neighborEntityIndex)
	table.clear(selfInternal._flatPositionX)
	table.clear(selfInternal._flatPositionY)
	table.clear(selfInternal._radius)
	table.clear(selfInternal._flowVelocityX)
	table.clear(selfInternal._flowVelocityY)
	table.clear(selfInternal._previousVelocityX)
	table.clear(selfInternal._previousVelocityY)
	table.clear(selfInternal._walkSpeed)
	table.clear(selfInternal._velAlpha)
	table.clear(selfInternal._isSettled)
	table.clear(selfInternal._touchedSettledNeighborByEntity)
	table.clear(selfInternal._goalGroupIdByGoalKey)
	table.clear(selfInternal._scratchGxByEntityIndex)
	table.clear(selfInternal._scratchGzByEntityIndex)
	table.clear(selfInternal._scratchSeenStampByEntityIndex)
	selfInternal._scratchNeighborStamp = 0

	for _, goalKey in ipairs(selfInternal._activeGoalKeys) do
		local entityIndices = selfInternal._entityIndicesByGoalKey[goalKey]
		if entityIndices ~= nil then
			table.clear(entityIndices)
		end
	end

	table.clear(selfInternal._activeGoalKeys)
	_ResetScratchCellBuckets(selfInternal)
	selfInternal._snapshot.WallPackedKeys = selfInternal._defaultWallPackedKeys
end

function FlowFrameState:EnsureGoalGroup(goalKey: string): number
	local selfInternal = self :: TFlowFrameStateInternal
	local existingGoalGroupId = selfInternal._goalGroupIdByGoalKey[goalKey]
	if existingGoalGroupId ~= nil then
		return existingGoalGroupId
	end

	local nextGoalGroupId = selfInternal._nextGoalGroupId + 1
	selfInternal._nextGoalGroupId = nextGoalGroupId
	selfInternal._goalGroupIdByGoalKey[goalKey] = nextGoalGroupId

	local entityIndices = selfInternal._entityIndicesByGoalKey[goalKey]
	if entityIndices == nil then
		entityIndices = _AcquireArray(selfInternal._recycler) :: { number }
		selfInternal._entityIndicesByGoalKey[goalKey] = entityIndices
	end

	selfInternal._activeGoalKeys[#selfInternal._activeGoalKeys + 1] = goalKey
	return nextGoalGroupId
end

function FlowFrameState:AddEntity(
	goalKey: string,
	entityId: number,
	position: Vector3,
	flowDirectionXZ: Vector2,
	walkSpeed: number,
	radius: number,
	previousVelocityXZ: Vector2,
	isSettled: boolean
): number
	local selfInternal = self :: TFlowFrameStateInternal
	local entityIndex = selfInternal._entityCount + 1
	local goalGroupId = self:EnsureGoalGroup(goalKey)
	local flatPosition = MovementMath.FlatXZ(position)
	local entityIndices = selfInternal._entityIndicesByGoalKey[goalKey]

	selfInternal._entityCount = entityIndex
	selfInternal._entityIds[entityIndex] = entityId
	selfInternal._goalGroupId[entityIndex] = goalGroupId
	selfInternal._flatPositionX[entityIndex] = flatPosition.X
	selfInternal._flatPositionY[entityIndex] = flatPosition.Y
	selfInternal._radius[entityIndex] = radius
	selfInternal._flowVelocityX[entityIndex] = flowDirectionXZ.X * walkSpeed
	selfInternal._flowVelocityY[entityIndex] = flowDirectionXZ.Y * walkSpeed
	selfInternal._previousVelocityX[entityIndex] = previousVelocityXZ.X
	selfInternal._previousVelocityY[entityIndex] = previousVelocityXZ.Y
	selfInternal._walkSpeed[entityIndex] = walkSpeed
	selfInternal._isSettled[entityIndex] = isSettled

	if entityIndices ~= nil then
		entityIndices[#entityIndices + 1] = entityIndex
	end

	return entityIndex
end

function FlowFrameState:GetEntityCount(): number
	return (self :: TFlowFrameStateInternal)._entityCount
end

function FlowFrameState:GetGoalBuckets(): { [string]: { number } }
	return (self :: TFlowFrameStateInternal)._entityIndicesByGoalKey
end

function FlowFrameState:GetEntityId(entityIndex: number): number?
	return (self :: TFlowFrameStateInternal)._entityIds[entityIndex]
end

function FlowFrameState:GetGoalGroupId(entityIndex: number): number?
	return (self :: TFlowFrameStateInternal)._goalGroupId[entityIndex]
end

function FlowFrameState:GetFlatPositionX(entityIndex: number): number?
	return (self :: TFlowFrameStateInternal)._flatPositionX[entityIndex]
end

function FlowFrameState:GetFlatPositionY(entityIndex: number): number?
	return (self :: TFlowFrameStateInternal)._flatPositionY[entityIndex]
end

function FlowFrameState:GetRadius(entityIndex: number): number?
	return (self :: TFlowFrameStateInternal)._radius[entityIndex]
end

function FlowFrameState:GetFlowVelocityX(entityIndex: number): number?
	return (self :: TFlowFrameStateInternal)._flowVelocityX[entityIndex]
end

function FlowFrameState:GetFlowVelocityY(entityIndex: number): number?
	return (self :: TFlowFrameStateInternal)._flowVelocityY[entityIndex]
end

function FlowFrameState:GetPreviousVelocityX(entityIndex: number): number?
	return (self :: TFlowFrameStateInternal)._previousVelocityX[entityIndex]
end

function FlowFrameState:GetPreviousVelocityY(entityIndex: number): number?
	return (self :: TFlowFrameStateInternal)._previousVelocityY[entityIndex]
end

function FlowFrameState:GetWalkSpeed(entityIndex: number): number?
	return (self :: TFlowFrameStateInternal)._walkSpeed[entityIndex]
end

function FlowFrameState:GetVelAlpha(entityIndex: number): number?
	return (self :: TFlowFrameStateInternal)._velAlpha[entityIndex]
end

function FlowFrameState:IsSettled(entityIndex: number): boolean
	return (self :: TFlowFrameStateInternal)._isSettled[entityIndex] == true
end

function FlowFrameState:SetVelAlpha(entityIndex: number, velAlpha: number)
	(self :: TFlowFrameStateInternal)._velAlpha[entityIndex] = velAlpha
end

function FlowFrameState:BuildSeparationSnapshot(
	params: TFlowFrameStateBuildSnapshotParams
): (TFlowSeparationSolveSnapshot, { [number]: boolean })
	local selfInternal = self :: TFlowFrameStateInternal
	local snapshot = selfInternal._snapshot

	snapshot.TickId = params.TickId
	snapshot.EntityCount = selfInternal._entityCount
	snapshot.DeltaTime = params.DeltaTime
	snapshot.CellWidthStuds = params.CellWidthStuds
	snapshot.OriginX = params.OriginX
	snapshot.OriginY = params.OriginY
	snapshot.WallGridHalfSize = params.WallGridHalfSize
	snapshot.WallPackedKeys = params.WallPackedKeys
	snapshot.KForce = params.KForce
	snapshot.MinSeparationDistance = params.MinSeparationDistance
	snapshot.WallCollisionEnabled = params.WallCollisionEnabled
	snapshot.WallCollisionAxisClampEnabled = params.WallCollisionAxisClampEnabled
	snapshot.WallCollisionCornerClampEnabled = params.WallCollisionCornerClampEnabled
	snapshot.WallCollisionUseUnitRadiusPadding = params.WallCollisionUseUnitRadiusPadding
	snapshot.WallCollisionCellProbePaddingStuds = params.WallCollisionCellProbePaddingStuds
	snapshot.WallCollisionVelocityEpsilon = params.WallCollisionVelocityEpsilon

	for _, goalKey in ipairs(selfInternal._activeGoalKeys) do
		local entityIndices = selfInternal._entityIndicesByGoalKey[goalKey]
		if entityIndices ~= nil and #entityIndices > 0 then
			_AppendGoalNeighborhoodData(selfInternal, entityIndices, params.ClumpTouchPaddingStuds)
		end
	end

	return snapshot, selfInternal._touchedSettledNeighborByEntity
end

function FlowFrameState:Destroy(): (boolean, string?)
	local selfInternal = self :: TFlowFrameStateInternal
	if selfInternal._destroyed then
		return true, nil
	end

	selfInternal:Reset()
	selfInternal._destroyed = true

	_ReleaseTrackedMap(selfInternal, selfInternal._snapshot :: any)
	_ReleaseTrackedArray(selfInternal, selfInternal._isSettled :: any)
	_ReleaseTrackedMap(selfInternal, selfInternal._entityIndicesByGoalKey :: any)
	_ReleaseTrackedArray(selfInternal, selfInternal._activeGoalKeys :: any)
	_ReleaseTrackedMap(selfInternal, selfInternal._goalGroupIdByGoalKey :: any)
	_ReleaseTrackedMap(selfInternal, selfInternal._touchedSettledNeighborByEntity :: any)
	_ReleaseTrackedMap(selfInternal, selfInternal._scratchBucketsByCell :: any)
	_ReleaseTrackedArray(selfInternal, selfInternal._scratchCellKeys :: any)
	_ReleaseTrackedArray(selfInternal, selfInternal._scratchFreeCellBuckets :: any)
	_ReleaseTrackedArray(selfInternal, selfInternal._scratchGxByEntityIndex :: any)
	_ReleaseTrackedArray(selfInternal, selfInternal._scratchGzByEntityIndex :: any)
	_ReleaseTrackedArray(selfInternal, selfInternal._scratchSeenStampByEntityIndex :: any)

	return true, nil
end

return table.freeze(FlowFrameState)
