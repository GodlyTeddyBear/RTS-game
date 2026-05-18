--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TableRecycler = require(ReplicatedStorage.Utilities.TableRecycler)
local FlowNeighborhoodMath = require(script.Parent.Math.FlowNeighborhoodMath)
local MovementMath = require(script.Parent.Math.MovementMath)
local MovementTypes = require(script.Parent.Types)

type TTableRecyclerHandle = TableRecycler.TTableRecyclerHandle
type TFlowFrameStateHandle = MovementTypes.TFlowFrameStateHandle
type TFlowSeparationSolveSnapshot = MovementTypes.TFlowSeparationSolveSnapshot

type TFlowFrameStateInternal = TFlowFrameStateHandle & {
	_destroyed: boolean,
	_recycler: TTableRecyclerHandle,
	_entityCount: number,
	_entityIds: { number },
	_goalGroupId: { number },
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
	_snapshotEntityIds: { number },
	_snapshotGoalGroupId: { number },
	_snapshotGoalGroupStartIndex: { number },
	_snapshotGoalGroupCount: { number },
	_snapshotGoalGroupCellWidthStuds: { number },
	_snapshotGroupCellX: { number },
	_snapshotGroupCellY: { number },
	_snapshotFlatPositionX: { number },
	_snapshotFlatPositionY: { number },
	_snapshotRadius: { number },
	_snapshotFlowVelocityX: { number },
	_snapshotFlowVelocityY: { number },
	_snapshotPreviousVelocityX: { number },
	_snapshotPreviousVelocityY: { number },
	_snapshotWalkSpeed: { number },
	_snapshotVelAlpha: { number },
	_snapshotIsSettled: { boolean },
	_snapshot: TFlowSeparationSolveSnapshot,
	_defaultWallPackedKeys: { number },
	_entityIndicesByGoalKey: { [string]: { number } },
	_activeGoalKeys: { string },
	_goalGroupIdByGoalKey: { [string]: number },
	_nextGoalGroupId: number,
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

local function _CopyRawEntityToSnapshot(
	self: TFlowFrameStateInternal,
	snapshotEntityIndex: number,
	rawEntityIndex: number,
	groupStartIndex: number,
	groupCount: number,
	groupCellWidthStuds: number
)
	local flatPositionX = self._flatPositionX[rawEntityIndex] or 0
	local flatPositionY = self._flatPositionY[rawEntityIndex] or 0
	local groupCellX, groupCellY =
		MovementMath.FlatPositionToCell(Vector2.new(flatPositionX, flatPositionY), groupCellWidthStuds)

	self._snapshotEntityIds[snapshotEntityIndex] = self._entityIds[rawEntityIndex]
	self._snapshotGoalGroupId[snapshotEntityIndex] = self._goalGroupId[rawEntityIndex]
	self._snapshotGoalGroupStartIndex[snapshotEntityIndex] = groupStartIndex
	self._snapshotGoalGroupCount[snapshotEntityIndex] = groupCount
	self._snapshotGoalGroupCellWidthStuds[snapshotEntityIndex] = groupCellWidthStuds
	self._snapshotGroupCellX[snapshotEntityIndex] = groupCellX
	self._snapshotGroupCellY[snapshotEntityIndex] = groupCellY
	self._snapshotFlatPositionX[snapshotEntityIndex] = flatPositionX
	self._snapshotFlatPositionY[snapshotEntityIndex] = flatPositionY
	self._snapshotRadius[snapshotEntityIndex] = self._radius[rawEntityIndex]
	self._snapshotFlowVelocityX[snapshotEntityIndex] = self._flowVelocityX[rawEntityIndex]
	self._snapshotFlowVelocityY[snapshotEntityIndex] = self._flowVelocityY[rawEntityIndex]
	self._snapshotPreviousVelocityX[snapshotEntityIndex] = self._previousVelocityX[rawEntityIndex]
	self._snapshotPreviousVelocityY[snapshotEntityIndex] = self._previousVelocityY[rawEntityIndex]
	self._snapshotWalkSpeed[snapshotEntityIndex] = self._walkSpeed[rawEntityIndex]
	self._snapshotVelAlpha[snapshotEntityIndex] = self._velAlpha[rawEntityIndex]
	self._snapshotIsSettled[snapshotEntityIndex] = self._isSettled[rawEntityIndex]
end

function FlowFrameState.new(recycler: TTableRecyclerHandle): TFlowFrameStateHandle
	local entityIds = _AcquireArray(recycler) :: { number }
	local goalGroupId = _AcquireArray(recycler) :: { number }
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

	local snapshotEntityIds = _AcquireArray(recycler) :: { number }
	local snapshotGoalGroupId = _AcquireArray(recycler) :: { number }
	local snapshotGoalGroupStartIndex = _AcquireArray(recycler) :: { number }
	local snapshotGoalGroupCount = _AcquireArray(recycler) :: { number }
	local snapshotGoalGroupCellWidthStuds = _AcquireArray(recycler) :: { number }
	local snapshotGroupCellX = _AcquireArray(recycler) :: { number }
	local snapshotGroupCellY = _AcquireArray(recycler) :: { number }
	local snapshotFlatPositionX = _AcquireArray(recycler) :: { number }
	local snapshotFlatPositionY = _AcquireArray(recycler) :: { number }
	local snapshotRadius = _AcquireArray(recycler) :: { number }
	local snapshotFlowVelocityX = _AcquireArray(recycler) :: { number }
	local snapshotFlowVelocityY = _AcquireArray(recycler) :: { number }
	local snapshotPreviousVelocityX = _AcquireArray(recycler) :: { number }
	local snapshotPreviousVelocityY = _AcquireArray(recycler) :: { number }
	local snapshotWalkSpeed = _AcquireArray(recycler) :: { number }
	local snapshotVelAlpha = _AcquireArray(recycler) :: { number }
	local snapshotIsSettled = _AcquireArray(recycler) :: { boolean }

	local defaultWallPackedKeys = _AcquireArray(recycler) :: { number }
	local entityIndicesByGoalKey = _AcquireMap(recycler) :: { [string]: { number } }
	local activeGoalKeys = _AcquireArray(recycler) :: { string }
	local goalGroupIdByGoalKey = _AcquireMap(recycler) :: { [string]: number }
	local snapshot = _AcquireMap(recycler) :: any

	snapshot.TickId = 0
	snapshot.EntityCount = 0
	snapshot.EntityIds = snapshotEntityIds
	snapshot.GoalGroupId = snapshotGoalGroupId
	snapshot.GoalGroupStartIndex = snapshotGoalGroupStartIndex
	snapshot.GoalGroupCount = snapshotGoalGroupCount
	snapshot.GoalGroupCellWidthStuds = snapshotGoalGroupCellWidthStuds
	snapshot.GroupCellX = snapshotGroupCellX
	snapshot.GroupCellY = snapshotGroupCellY
	snapshot.FlatPositionX = snapshotFlatPositionX
	snapshot.FlatPositionY = snapshotFlatPositionY
	snapshot.Radius = snapshotRadius
	snapshot.FlowVelocityX = snapshotFlowVelocityX
	snapshot.FlowVelocityY = snapshotFlowVelocityY
	snapshot.PreviousVelocityX = snapshotPreviousVelocityX
	snapshot.PreviousVelocityY = snapshotPreviousVelocityY
	snapshot.WalkSpeed = snapshotWalkSpeed
	snapshot.VelAlpha = snapshotVelAlpha
	snapshot.IsSettled = snapshotIsSettled
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
	snapshot.ClumpTouchPaddingStuds = 0

	local self = setmetatable({
		_destroyed = false,
		_recycler = recycler,
		_entityCount = 0,
		_entityIds = entityIds,
		_goalGroupId = goalGroupId,
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
		_snapshotEntityIds = snapshotEntityIds,
		_snapshotGoalGroupId = snapshotGoalGroupId,
		_snapshotGoalGroupStartIndex = snapshotGoalGroupStartIndex,
		_snapshotGoalGroupCount = snapshotGoalGroupCount,
		_snapshotGoalGroupCellWidthStuds = snapshotGoalGroupCellWidthStuds,
		_snapshotGroupCellX = snapshotGroupCellX,
		_snapshotGroupCellY = snapshotGroupCellY,
		_snapshotFlatPositionX = snapshotFlatPositionX,
		_snapshotFlatPositionY = snapshotFlatPositionY,
		_snapshotRadius = snapshotRadius,
		_snapshotFlowVelocityX = snapshotFlowVelocityX,
		_snapshotFlowVelocityY = snapshotFlowVelocityY,
		_snapshotPreviousVelocityX = snapshotPreviousVelocityX,
		_snapshotPreviousVelocityY = snapshotPreviousVelocityY,
		_snapshotWalkSpeed = snapshotWalkSpeed,
		_snapshotVelAlpha = snapshotVelAlpha,
		_snapshotIsSettled = snapshotIsSettled,
		_snapshot = snapshot :: TFlowSeparationSolveSnapshot,
		_defaultWallPackedKeys = defaultWallPackedKeys,
		_entityIndicesByGoalKey = entityIndicesByGoalKey,
		_activeGoalKeys = activeGoalKeys,
		_goalGroupIdByGoalKey = goalGroupIdByGoalKey,
		_nextGoalGroupId = 0,
	}, FlowFrameState)

	return self :: TFlowFrameStateHandle
end

function FlowFrameState:Reset()
	local selfInternal = self :: TFlowFrameStateInternal
	selfInternal._entityCount = 0
	selfInternal._nextGoalGroupId = 0

	table.clear(selfInternal._entityIds)
	table.clear(selfInternal._goalGroupId)
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

	table.clear(selfInternal._snapshotEntityIds)
	table.clear(selfInternal._snapshotGoalGroupId)
	table.clear(selfInternal._snapshotGoalGroupStartIndex)
	table.clear(selfInternal._snapshotGoalGroupCount)
	table.clear(selfInternal._snapshotGoalGroupCellWidthStuds)
	table.clear(selfInternal._snapshotGroupCellX)
	table.clear(selfInternal._snapshotGroupCellY)
	table.clear(selfInternal._snapshotFlatPositionX)
	table.clear(selfInternal._snapshotFlatPositionY)
	table.clear(selfInternal._snapshotRadius)
	table.clear(selfInternal._snapshotFlowVelocityX)
	table.clear(selfInternal._snapshotFlowVelocityY)
	table.clear(selfInternal._snapshotPreviousVelocityX)
	table.clear(selfInternal._snapshotPreviousVelocityY)
	table.clear(selfInternal._snapshotWalkSpeed)
	table.clear(selfInternal._snapshotVelAlpha)
	table.clear(selfInternal._snapshotIsSettled)
	table.clear(selfInternal._goalGroupIdByGoalKey)

	for _, goalKey in ipairs(selfInternal._activeGoalKeys) do
		local entityIndices = selfInternal._entityIndicesByGoalKey[goalKey]
		if entityIndices ~= nil then
			table.clear(entityIndices)
		end
	end

	table.clear(selfInternal._activeGoalKeys)
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
	tickId: number,
	deltaTime: number,
	cellWidthStuds: number,
	originX: number,
	originY: number,
	wallGridHalfSize: number,
	wallPackedKeys: { number },
	kForce: number,
	minSeparationDistance: number,
	wallCollisionEnabled: boolean,
	wallCollisionAxisClampEnabled: boolean,
	wallCollisionCornerClampEnabled: boolean,
	wallCollisionUseUnitRadiusPadding: boolean,
	wallCollisionCellProbePaddingStuds: number,
	wallCollisionVelocityEpsilon: number,
	clumpTouchPaddingStuds: number
): TFlowSeparationSolveSnapshot
	local selfInternal = self :: TFlowFrameStateInternal
	local snapshot = selfInternal._snapshot
	local orderedEntityCount = 0

	table.clear(selfInternal._snapshotEntityIds)
	table.clear(selfInternal._snapshotGoalGroupId)
	table.clear(selfInternal._snapshotGoalGroupStartIndex)
	table.clear(selfInternal._snapshotGoalGroupCount)
	table.clear(selfInternal._snapshotGoalGroupCellWidthStuds)
	table.clear(selfInternal._snapshotGroupCellX)
	table.clear(selfInternal._snapshotGroupCellY)
	table.clear(selfInternal._snapshotFlatPositionX)
	table.clear(selfInternal._snapshotFlatPositionY)
	table.clear(selfInternal._snapshotRadius)
	table.clear(selfInternal._snapshotFlowVelocityX)
	table.clear(selfInternal._snapshotFlowVelocityY)
	table.clear(selfInternal._snapshotPreviousVelocityX)
	table.clear(selfInternal._snapshotPreviousVelocityY)
	table.clear(selfInternal._snapshotWalkSpeed)
	table.clear(selfInternal._snapshotVelAlpha)
	table.clear(selfInternal._snapshotIsSettled)

	for _, goalKey in ipairs(selfInternal._activeGoalKeys) do
		local entityIndices = selfInternal._entityIndicesByGoalKey[goalKey]
		if entityIndices ~= nil and #entityIndices > 0 then
			local groupStartIndex = orderedEntityCount + 1
			local groupCount = #entityIndices
			local groupCellWidthStuds = FlowNeighborhoodMath.ResolveCellWidthForEntityIndices(self, entityIndices)

			for _, rawEntityIndex in ipairs(entityIndices) do
				orderedEntityCount += 1
				_CopyRawEntityToSnapshot(
					selfInternal,
					orderedEntityCount,
					rawEntityIndex,
					groupStartIndex,
					groupCount,
					groupCellWidthStuds
				)
			end
		end
	end

	snapshot.TickId = tickId
	snapshot.EntityCount = orderedEntityCount
	snapshot.DeltaTime = deltaTime
	snapshot.CellWidthStuds = cellWidthStuds
	snapshot.OriginX = originX
	snapshot.OriginY = originY
	snapshot.WallGridHalfSize = wallGridHalfSize
	snapshot.WallPackedKeys = wallPackedKeys
	snapshot.KForce = kForce
	snapshot.MinSeparationDistance = minSeparationDistance
	snapshot.WallCollisionEnabled = wallCollisionEnabled
	snapshot.WallCollisionAxisClampEnabled = wallCollisionAxisClampEnabled
	snapshot.WallCollisionCornerClampEnabled = wallCollisionCornerClampEnabled
	snapshot.WallCollisionUseUnitRadiusPadding = wallCollisionUseUnitRadiusPadding
	snapshot.WallCollisionCellProbePaddingStuds = wallCollisionCellProbePaddingStuds
	snapshot.WallCollisionVelocityEpsilon = wallCollisionVelocityEpsilon
	snapshot.ClumpTouchPaddingStuds = clumpTouchPaddingStuds

	return snapshot
end

function FlowFrameState:Destroy(): (boolean, string?)
	local selfInternal = self :: TFlowFrameStateInternal
	if selfInternal._destroyed then
		return true, nil
	end

	selfInternal:Reset()
	selfInternal._destroyed = true

	_ReleaseTrackedMap(selfInternal, selfInternal._snapshot :: any)
	_ReleaseTrackedArray(selfInternal, selfInternal._entityIds :: any)
	_ReleaseTrackedArray(selfInternal, selfInternal._goalGroupId :: any)
	_ReleaseTrackedArray(selfInternal, selfInternal._flatPositionX :: any)
	_ReleaseTrackedArray(selfInternal, selfInternal._flatPositionY :: any)
	_ReleaseTrackedArray(selfInternal, selfInternal._radius :: any)
	_ReleaseTrackedArray(selfInternal, selfInternal._flowVelocityX :: any)
	_ReleaseTrackedArray(selfInternal, selfInternal._flowVelocityY :: any)
	_ReleaseTrackedArray(selfInternal, selfInternal._previousVelocityX :: any)
	_ReleaseTrackedArray(selfInternal, selfInternal._previousVelocityY :: any)
	_ReleaseTrackedArray(selfInternal, selfInternal._walkSpeed :: any)
	_ReleaseTrackedArray(selfInternal, selfInternal._velAlpha :: any)
	_ReleaseTrackedArray(selfInternal, selfInternal._isSettled :: any)
	_ReleaseTrackedMap(selfInternal, selfInternal._entityIndicesByGoalKey :: any)
	_ReleaseTrackedArray(selfInternal, selfInternal._activeGoalKeys :: any)
	_ReleaseTrackedMap(selfInternal, selfInternal._goalGroupIdByGoalKey :: any)

	return true, nil
end

return table.freeze(FlowFrameState)
