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
	_snapshotGoalGroupCellRecordStartIndex: { number },
	_snapshotGoalGroupCellRecordCount: { number },
	_snapshotGoalGroupCellWidthStuds: { number },
	_snapshotGroupCellX: { number },
	_snapshotGroupCellY: { number },
	_snapshotCellPackedKey: { number },
	_snapshotCellMemberStartIndex: { number },
	_snapshotCellMemberCount: { number },
	_snapshotCellMemberEntityIndex: { number },
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
	_scratchBucketsByCellPackedKey: { [number]: { number } },
	_scratchCellPackedKeys: { number },
	_scratchFreeCellBuckets: { { number } },
}

--[=[
    @class FlowFrameState
    Owns the packed per-frame movement buffers used to build flow separation snapshots.

    The frame is reset, filled with flow entities, and then converted into a
    structure-of-arrays snapshot for the parallel separation solve.
    @server
]=]
local FlowFrameState = {}
FlowFrameState.__index = FlowFrameState

-- Acquire a fresh array from the recycler so frame-state buffers stay pooled.
local function _AcquireArray(recycler: TTableRecyclerHandle): { any }
	return recycler:AcquireArray()
end

-- Acquire a fresh map from the recycler so frame-state lookup tables stay pooled.
local function _AcquireMap(recycler: TTableRecyclerHandle): { [any]: any }
	return recycler:AcquireMap()
end

-- Release a pooled array after the frame-state has finished with it.
local function _ReleaseTrackedArray(self: TFlowFrameStateInternal, tbl: { any })
	local didRelease, releaseError = self._recycler:ReleaseArray(tbl)
	assert(didRelease, releaseError)
end

-- Release a pooled map after the frame-state has finished with it.
local function _ReleaseTrackedMap(self: TFlowFrameStateInternal, tbl: { [any]: any })
	local didRelease, releaseError = self._recycler:ReleaseMap(tbl)
	assert(didRelease, releaseError)
end

-- Reuse a scratch bucket when grouping entities by cell during snapshot builds.
local function _AcquireScratchCellBucket(self: TFlowFrameStateInternal): { number }
	local freeBuckets = self._scratchFreeCellBuckets
	local bucket = freeBuckets[#freeBuckets]
	if bucket ~= nil then
		freeBuckets[#freeBuckets] = nil
		return bucket
	end

	return _AcquireArray(self._recycler) :: { number }
end

-- Clear scratch buckets between goal groups so each group builds its own cell grouping.
local function _ResetScratchCellBuckets(self: TFlowFrameStateInternal)
	local scratchBucketsByCellPackedKey = self._scratchBucketsByCellPackedKey
	local scratchCellPackedKeys = self._scratchCellPackedKeys
	local scratchFreeCellBuckets = self._scratchFreeCellBuckets

	for _, cellPackedKey in ipairs(scratchCellPackedKeys) do
		local bucket = scratchBucketsByCellPackedKey[cellPackedKey]
		if bucket ~= nil then
			table.clear(bucket)
			scratchBucketsByCellPackedKey[cellPackedKey] = nil
			scratchFreeCellBuckets[#scratchFreeCellBuckets + 1] = bucket
		end
	end

	table.clear(scratchCellPackedKeys)
end

-- Release the goal-group arrays that track packed entity membership for each goal key.
local function _ReleaseGoalBucketArrays(self: TFlowFrameStateInternal)
	for goalKey, entityIndices in self._entityIndicesByGoalKey do
		if entityIndices ~= nil then
			table.clear(entityIndices)
			_ReleaseTrackedArray(self, entityIndices)
			self._entityIndicesByGoalKey[goalKey] = nil
		end
	end
end

-- Release the scratch arrays used while building the separation snapshot.
local function _ReleaseScratchBucketArrays(self: TFlowFrameStateInternal)
	for cellPackedKey, bucket in self._scratchBucketsByCellPackedKey do
		if bucket ~= nil then
			table.clear(bucket)
			_ReleaseTrackedArray(self, bucket)
			self._scratchBucketsByCellPackedKey[cellPackedKey] = nil
		end
	end

	local scratchFreeCellBuckets = self._scratchFreeCellBuckets
	for index = #scratchFreeCellBuckets, 1, -1 do
		local bucket = scratchFreeCellBuckets[index]
		if bucket ~= nil then
			table.clear(bucket)
			_ReleaseTrackedArray(self, bucket)
			scratchFreeCellBuckets[index] = nil
		end
	end
end

-- Strip the cached snapshot table so destruction leaves no live references behind.
local function _ClearSnapshotForDestroy(self: TFlowFrameStateInternal)
	local snapshot = self._snapshot :: any
	snapshot.TickId = nil
	snapshot.EntityCount = nil
	snapshot.EntityIds = nil
	snapshot.GoalGroupId = nil
	snapshot.GoalGroupCellRecordStartIndex = nil
	snapshot.GoalGroupCellRecordCount = nil
	snapshot.GoalGroupCellWidthStuds = nil
	snapshot.GroupCellX = nil
	snapshot.GroupCellY = nil
	snapshot.CellPackedKey = nil
	snapshot.CellMemberStartIndex = nil
	snapshot.CellMemberCount = nil
	snapshot.CellMemberEntityIndex = nil
	snapshot.FlatPositionX = nil
	snapshot.FlatPositionY = nil
	snapshot.Radius = nil
	snapshot.FlowVelocityX = nil
	snapshot.FlowVelocityY = nil
	snapshot.PreviousVelocityX = nil
	snapshot.PreviousVelocityY = nil
	snapshot.WalkSpeed = nil
	snapshot.VelAlpha = nil
	snapshot.IsSettled = nil
	snapshot.DeltaTime = nil
	snapshot.CellWidthStuds = nil
	snapshot.OriginX = nil
	snapshot.OriginY = nil
	snapshot.WallGridHalfSize = nil
	snapshot.WallPackedKeys = nil
	snapshot.KForce = nil
	snapshot.MinSeparationDistance = nil
	snapshot.WallCollisionEnabled = nil
	snapshot.WallCollisionAxisClampEnabled = nil
	snapshot.WallCollisionCornerClampEnabled = nil
	snapshot.WallCollisionUseUnitRadiusPadding = nil
	snapshot.WallCollisionCellProbePaddingStuds = nil
	snapshot.WallCollisionVelocityEpsilon = nil
	snapshot.ClumpTouchPaddingStuds = nil
end

-- Copy one packed entity into the snapshot buffers and return its cell key.
local function _CopyRawEntityToSnapshot(
	self: TFlowFrameStateInternal,
	snapshotEntityIndex: number,
	rawEntityIndex: number,
	groupCellWidthStuds: number
): number
	local flatPositionX = self._flatPositionX[rawEntityIndex] or 0
	local flatPositionY = self._flatPositionY[rawEntityIndex] or 0
	local groupCellX, groupCellY =
		MovementMath.FlatPositionToCell(Vector2.new(flatPositionX, flatPositionY), groupCellWidthStuds)

	self._snapshotEntityIds[snapshotEntityIndex] = self._entityIds[rawEntityIndex]
	self._snapshotGoalGroupId[snapshotEntityIndex] = self._goalGroupId[rawEntityIndex]
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

	return MovementMath.PackedSeparationCellKey(groupCellX, groupCellY)
end

--[=[
    Creates a new flow frame-state handle backed by recycler-managed buffers.
    @within FlowFrameState
    @param recycler TTableRecyclerHandle -- Recycler used to source the frame buffers.
    @return TFlowFrameStateHandle -- Frame-state handle used by the movement service.
]=]
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
	local snapshotGoalGroupCellRecordStartIndex = _AcquireArray(recycler) :: { number }
	local snapshotGoalGroupCellRecordCount = _AcquireArray(recycler) :: { number }
	local snapshotGoalGroupCellWidthStuds = _AcquireArray(recycler) :: { number }
	local snapshotGroupCellX = _AcquireArray(recycler) :: { number }
	local snapshotGroupCellY = _AcquireArray(recycler) :: { number }
	local snapshotCellPackedKey = _AcquireArray(recycler) :: { number }
	local snapshotCellMemberStartIndex = _AcquireArray(recycler) :: { number }
	local snapshotCellMemberCount = _AcquireArray(recycler) :: { number }
	local snapshotCellMemberEntityIndex = _AcquireArray(recycler) :: { number }
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
	local scratchBucketsByCellPackedKey = _AcquireMap(recycler) :: { [number]: { number } }
	local scratchCellPackedKeys = _AcquireArray(recycler) :: { number }
	local scratchFreeCellBuckets = _AcquireArray(recycler) :: { { number } }
	local snapshot = _AcquireMap(recycler) :: any

	snapshot.TickId = 0
	snapshot.EntityCount = 0
	snapshot.EntityIds = snapshotEntityIds
	snapshot.GoalGroupId = snapshotGoalGroupId
	snapshot.GoalGroupCellRecordStartIndex = snapshotGoalGroupCellRecordStartIndex
	snapshot.GoalGroupCellRecordCount = snapshotGoalGroupCellRecordCount
	snapshot.GoalGroupCellWidthStuds = snapshotGoalGroupCellWidthStuds
	snapshot.GroupCellX = snapshotGroupCellX
	snapshot.GroupCellY = snapshotGroupCellY
	snapshot.CellPackedKey = snapshotCellPackedKey
	snapshot.CellMemberStartIndex = snapshotCellMemberStartIndex
	snapshot.CellMemberCount = snapshotCellMemberCount
	snapshot.CellMemberEntityIndex = snapshotCellMemberEntityIndex
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
		_snapshotGoalGroupCellRecordStartIndex = snapshotGoalGroupCellRecordStartIndex,
		_snapshotGoalGroupCellRecordCount = snapshotGoalGroupCellRecordCount,
		_snapshotGoalGroupCellWidthStuds = snapshotGoalGroupCellWidthStuds,
		_snapshotGroupCellX = snapshotGroupCellX,
		_snapshotGroupCellY = snapshotGroupCellY,
		_snapshotCellPackedKey = snapshotCellPackedKey,
		_snapshotCellMemberStartIndex = snapshotCellMemberStartIndex,
		_snapshotCellMemberCount = snapshotCellMemberCount,
		_snapshotCellMemberEntityIndex = snapshotCellMemberEntityIndex,
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
		_scratchBucketsByCellPackedKey = scratchBucketsByCellPackedKey,
		_scratchCellPackedKeys = scratchCellPackedKeys,
		_scratchFreeCellBuckets = scratchFreeCellBuckets,
	}, FlowFrameState)

	return self :: TFlowFrameStateHandle
end

--[=[
    Clears the accumulated frame-state buffers so the handle can be reused.
    @within FlowFrameState
]=]
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
	table.clear(selfInternal._snapshotGoalGroupCellRecordStartIndex)
	table.clear(selfInternal._snapshotGoalGroupCellRecordCount)
	table.clear(selfInternal._snapshotGoalGroupCellWidthStuds)
	table.clear(selfInternal._snapshotGroupCellX)
	table.clear(selfInternal._snapshotGroupCellY)
	table.clear(selfInternal._snapshotCellPackedKey)
	table.clear(selfInternal._snapshotCellMemberStartIndex)
	table.clear(selfInternal._snapshotCellMemberCount)
	table.clear(selfInternal._snapshotCellMemberEntityIndex)
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
	_ResetScratchCellBuckets(selfInternal)
	selfInternal._snapshot.WallPackedKeys = selfInternal._defaultWallPackedKeys
end

--[=[
    Returns the stable goal-group id for a goal key, allocating one when needed.
    @within FlowFrameState
    @param goalKey string -- Shared flowfield goal key.
    @return number -- Packed goal-group id for the key.
]=]
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

--[=[
    Adds one entity to the current frame-state buffers.
    @within FlowFrameState
    @param goalKey string -- Shared flowfield goal key for the entity.
    @param entityId number -- Entity id to append.
    @param position Vector3 -- Current world position for the entity.
    @param flowDirectionXZ Vector2 -- Resolved flow direction in XZ space.
    @param walkSpeed number -- Current walk speed used to derive velocity.
    @param radius number -- Agent radius used by the separation solve.
    @param previousVelocityXZ Vector2 -- Previous frame velocity in XZ space.
    @param isSettled boolean -- Whether the entity is currently settled at its goal.
    @return number -- Packed snapshot entity index.
]=]
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

--[=[
    Returns how many entities are currently packed into the frame-state.
    @within FlowFrameState
    @return number -- Entity count.
]=]
function FlowFrameState:GetEntityCount(): number
	return (self :: TFlowFrameStateInternal)._entityCount
end

--[=[
    Returns the goal-bucket map used while grouping entities for the solve.
    @within FlowFrameState
    @return { [string]: { number } } -- Goal-key to packed entity index buckets.
]=]
function FlowFrameState:GetGoalBuckets(): { [string]: { number } }
	return (self :: TFlowFrameStateInternal)._entityIndicesByGoalKey
end

--[=[
    Returns the packed entity id at one snapshot index.
    @within FlowFrameState
    @param entityIndex number -- Packed snapshot entity index.
    @return number? -- Entity id or `nil` when the index is out of range.
]=]
function FlowFrameState:GetEntityId(entityIndex: number): number?
	return (self :: TFlowFrameStateInternal)._entityIds[entityIndex]
end

--[=[
    Returns the packed goal-group id at one snapshot index.
    @within FlowFrameState
    @param entityIndex number -- Packed snapshot entity index.
    @return number? -- Goal-group id or `nil` when the index is out of range.
]=]
function FlowFrameState:GetGoalGroupId(entityIndex: number): number?
	return (self :: TFlowFrameStateInternal)._goalGroupId[entityIndex]
end

--[=[
    Returns the packed flat-position X value at one snapshot index.
    @within FlowFrameState
    @param entityIndex number -- Packed snapshot entity index.
    @return number? -- Flat-position X component or `nil` when the index is out of range.
]=]
function FlowFrameState:GetFlatPositionX(entityIndex: number): number?
	return (self :: TFlowFrameStateInternal)._flatPositionX[entityIndex]
end

--[=[
    Returns the packed flat-position Y value at one snapshot index.
    @within FlowFrameState
    @param entityIndex number -- Packed snapshot entity index.
    @return number? -- Flat-position Y component or `nil` when the index is out of range.
]=]
function FlowFrameState:GetFlatPositionY(entityIndex: number): number?
	return (self :: TFlowFrameStateInternal)._flatPositionY[entityIndex]
end

--[=[
    Returns the packed radius value at one snapshot index.
    @within FlowFrameState
    @param entityIndex number -- Packed snapshot entity index.
    @return number? -- Radius or `nil` when the index is out of range.
]=]
function FlowFrameState:GetRadius(entityIndex: number): number?
	return (self :: TFlowFrameStateInternal)._radius[entityIndex]
end

--[=[
    Returns the packed flow-velocity X value at one snapshot index.
    @within FlowFrameState
    @param entityIndex number -- Packed snapshot entity index.
    @return number? -- Flow velocity X component or `nil` when the index is out of range.
]=]
function FlowFrameState:GetFlowVelocityX(entityIndex: number): number?
	return (self :: TFlowFrameStateInternal)._flowVelocityX[entityIndex]
end

--[=[
    Returns the packed flow-velocity Y value at one snapshot index.
    @within FlowFrameState
    @param entityIndex number -- Packed snapshot entity index.
    @return number? -- Flow velocity Y component or `nil` when the index is out of range.
]=]
function FlowFrameState:GetFlowVelocityY(entityIndex: number): number?
	return (self :: TFlowFrameStateInternal)._flowVelocityY[entityIndex]
end

--[=[
    Returns the packed previous-velocity X value at one snapshot index.
    @within FlowFrameState
    @param entityIndex number -- Packed snapshot entity index.
    @return number? -- Previous velocity X component or `nil` when the index is out of range.
]=]
function FlowFrameState:GetPreviousVelocityX(entityIndex: number): number?
	return (self :: TFlowFrameStateInternal)._previousVelocityX[entityIndex]
end

--[=[
    Returns the packed previous-velocity Y value at one snapshot index.
    @within FlowFrameState
    @param entityIndex number -- Packed snapshot entity index.
    @return number? -- Previous velocity Y component or `nil` when the index is out of range.
]=]
function FlowFrameState:GetPreviousVelocityY(entityIndex: number): number?
	return (self :: TFlowFrameStateInternal)._previousVelocityY[entityIndex]
end

--[=[
    Returns the packed walk speed value at one snapshot index.
    @within FlowFrameState
    @param entityIndex number -- Packed snapshot entity index.
    @return number? -- Walk speed or `nil` when the index is out of range.
]=]
function FlowFrameState:GetWalkSpeed(entityIndex: number): number?
	return (self :: TFlowFrameStateInternal)._walkSpeed[entityIndex]
end

--[=[
    Returns the packed velocity-alpha value at one snapshot index.
    @within FlowFrameState
    @param entityIndex number -- Packed snapshot entity index.
    @return number? -- Velocity alpha or `nil` when the index is out of range.
]=]
function FlowFrameState:GetVelAlpha(entityIndex: number): number?
	return (self :: TFlowFrameStateInternal)._velAlpha[entityIndex]
end

--[=[
    Returns whether one packed entity index is marked settled.
    @within FlowFrameState
    @param entityIndex number -- Packed snapshot entity index.
    @return boolean -- Whether the entity is settled.
]=]
function FlowFrameState:IsSettled(entityIndex: number): boolean
	return (self :: TFlowFrameStateInternal)._isSettled[entityIndex] == true
end

--[=[
    Writes the velocity-alpha value for one packed entity index.
    @within FlowFrameState
    @param entityIndex number -- Packed snapshot entity index.
    @param velAlpha number -- Velocity blend factor to store.
]=]
function FlowFrameState:SetVelAlpha(entityIndex: number, velAlpha: number)
	(self :: TFlowFrameStateInternal)._velAlpha[entityIndex] = velAlpha
end

--[=[
    Builds the structure-of-arrays separation snapshot for the current frame.
    @within FlowFrameState
    @param tickId number -- Solver tick identifier to embed in the snapshot.
    @param deltaTime number -- Delta time used by the solver.
    @param cellWidthStuds number -- Cell width in studs.
    @param originX number -- World origin X coordinate.
    @param originY number -- World origin Z coordinate projected into Y.
    @param wallGridHalfSize number -- Half-size of the wall grid.
    @param wallPackedKeys { number } -- Packed wall cell keys.
    @param kForce number -- Separation force constant.
    @param minSeparationDistance number -- Minimum agent separation distance.
    @param wallCollisionEnabled boolean -- Whether wall collision is enabled.
    @param wallCollisionAxisClampEnabled boolean -- Whether axis clamp logic is enabled.
    @param wallCollisionCornerClampEnabled boolean -- Whether corner clamp logic is enabled.
    @param wallCollisionUseUnitRadiusPadding boolean -- Whether unit-radius padding is applied.
    @param wallCollisionCellProbePaddingStuds number -- Additional wall probe padding in studs.
    @param wallCollisionVelocityEpsilon number -- Velocity epsilon used by wall collision tests.
    @param clumpTouchPaddingStuds number -- Padding used for clump-touch checks.
    @return TFlowSeparationSolveSnapshot -- Packed separation solve snapshot.
]=]
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

	-- Clear all packed output buffers before rebuilding the snapshot for this tick.
	table.clear(selfInternal._snapshotEntityIds)
	table.clear(selfInternal._snapshotGoalGroupId)
	table.clear(selfInternal._snapshotGoalGroupCellRecordStartIndex)
	table.clear(selfInternal._snapshotGoalGroupCellRecordCount)
	table.clear(selfInternal._snapshotGoalGroupCellWidthStuds)
	table.clear(selfInternal._snapshotGroupCellX)
	table.clear(selfInternal._snapshotGroupCellY)
	table.clear(selfInternal._snapshotCellPackedKey)
	table.clear(selfInternal._snapshotCellMemberStartIndex)
	table.clear(selfInternal._snapshotCellMemberCount)
	table.clear(selfInternal._snapshotCellMemberEntityIndex)
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

	-- Pack each goal group and bucket entities by separation cell within that group.
	for _, goalKey in ipairs(selfInternal._activeGoalKeys) do
		local entityIndices = selfInternal._entityIndicesByGoalKey[goalKey]
		if entityIndices ~= nil and #entityIndices > 0 then
			local groupCellWidthStuds = FlowNeighborhoodMath.ResolveCellWidthForEntityIndices(self, entityIndices)
			local groupStartSnapshotEntityIndex = orderedEntityCount + 1

			_ResetScratchCellBuckets(selfInternal)

			for _, rawEntityIndex in ipairs(entityIndices) do
				orderedEntityCount += 1
				local cellPackedKey = _CopyRawEntityToSnapshot(
					selfInternal,
					orderedEntityCount,
					rawEntityIndex,
					groupCellWidthStuds
				)

				local cellBucket = selfInternal._scratchBucketsByCellPackedKey[cellPackedKey]
				if cellBucket == nil then
					cellBucket = _AcquireScratchCellBucket(selfInternal)
					selfInternal._scratchBucketsByCellPackedKey[cellPackedKey] = cellBucket
					selfInternal._scratchCellPackedKeys[#selfInternal._scratchCellPackedKeys + 1] = cellPackedKey
				end

				cellBucket[#cellBucket + 1] = orderedEntityCount
			end

			table.sort(selfInternal._scratchCellPackedKeys)

			local groupCellRecordStartIndex = #selfInternal._snapshotCellPackedKey + 1
			local groupCellRecordCount = #selfInternal._scratchCellPackedKeys
			for _, cellPackedKey in ipairs(selfInternal._scratchCellPackedKeys) do
				local cellBucket = selfInternal._scratchBucketsByCellPackedKey[cellPackedKey]
				if cellBucket ~= nil then
					local cellRecordIndex = #selfInternal._snapshotCellPackedKey + 1
					local memberStartIndex = #selfInternal._snapshotCellMemberEntityIndex + 1
					selfInternal._snapshotCellPackedKey[cellRecordIndex] = cellPackedKey
					selfInternal._snapshotCellMemberStartIndex[cellRecordIndex] = memberStartIndex
					selfInternal._snapshotCellMemberCount[cellRecordIndex] = #cellBucket

					for _, snapshotEntityIndex in ipairs(cellBucket) do
						selfInternal._snapshotCellMemberEntityIndex[#selfInternal._snapshotCellMemberEntityIndex + 1] =
							snapshotEntityIndex
					end
				end
			end

			for snapshotEntityIndex = groupStartSnapshotEntityIndex, orderedEntityCount do
				selfInternal._snapshotGoalGroupCellRecordStartIndex[snapshotEntityIndex] = groupCellRecordStartIndex
				selfInternal._snapshotGoalGroupCellRecordCount[snapshotEntityIndex] = groupCellRecordCount
			end

			_ResetScratchCellBuckets(selfInternal)
		end
	end

	-- Write the frame-level metadata and solver constants onto the cached snapshot table.
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

--[=[
    Releases all pooled buffers and marks the frame-state handle destroyed.
    @within FlowFrameState
    @return boolean -- Whether destroy completed successfully.
    @return string? -- Failure reason when destruction fails.
]=]
function FlowFrameState:Destroy(): (boolean, string?)
	local selfInternal = self :: TFlowFrameStateInternal
	if selfInternal._destroyed then
		return true, nil
	end

	-- Reset first so any pooled arrays are drained before release.
	selfInternal:Reset()
	selfInternal._destroyed = true

	-- Release the goal-group and scratch buckets before dropping the backing tables.
	_ReleaseGoalBucketArrays(selfInternal)
	_ReleaseScratchBucketArrays(selfInternal)
	_ClearSnapshotForDestroy(selfInternal)

	-- Return every recycler-backed buffer to the pool.
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
	_ReleaseTrackedArray(selfInternal, selfInternal._snapshotEntityIds :: any)
	_ReleaseTrackedArray(selfInternal, selfInternal._snapshotGoalGroupId :: any)
	_ReleaseTrackedArray(selfInternal, selfInternal._snapshotGoalGroupCellRecordStartIndex :: any)
	_ReleaseTrackedArray(selfInternal, selfInternal._snapshotGoalGroupCellRecordCount :: any)
	_ReleaseTrackedArray(selfInternal, selfInternal._snapshotGoalGroupCellWidthStuds :: any)
	_ReleaseTrackedArray(selfInternal, selfInternal._snapshotGroupCellX :: any)
	_ReleaseTrackedArray(selfInternal, selfInternal._snapshotGroupCellY :: any)
	_ReleaseTrackedArray(selfInternal, selfInternal._snapshotCellPackedKey :: any)
	_ReleaseTrackedArray(selfInternal, selfInternal._snapshotCellMemberStartIndex :: any)
	_ReleaseTrackedArray(selfInternal, selfInternal._snapshotCellMemberCount :: any)
	_ReleaseTrackedArray(selfInternal, selfInternal._snapshotCellMemberEntityIndex :: any)
	_ReleaseTrackedArray(selfInternal, selfInternal._snapshotFlatPositionX :: any)
	_ReleaseTrackedArray(selfInternal, selfInternal._snapshotFlatPositionY :: any)
	_ReleaseTrackedArray(selfInternal, selfInternal._snapshotRadius :: any)
	_ReleaseTrackedArray(selfInternal, selfInternal._snapshotFlowVelocityX :: any)
	_ReleaseTrackedArray(selfInternal, selfInternal._snapshotFlowVelocityY :: any)
	_ReleaseTrackedArray(selfInternal, selfInternal._snapshotPreviousVelocityX :: any)
	_ReleaseTrackedArray(selfInternal, selfInternal._snapshotPreviousVelocityY :: any)
	_ReleaseTrackedArray(selfInternal, selfInternal._snapshotWalkSpeed :: any)
	_ReleaseTrackedArray(selfInternal, selfInternal._snapshotVelAlpha :: any)
	_ReleaseTrackedArray(selfInternal, selfInternal._snapshotIsSettled :: any)
	_ReleaseTrackedArray(selfInternal, selfInternal._defaultWallPackedKeys :: any)
	_ReleaseTrackedMap(selfInternal, selfInternal._entityIndicesByGoalKey :: any)
	_ReleaseTrackedArray(selfInternal, selfInternal._activeGoalKeys :: any)
	_ReleaseTrackedMap(selfInternal, selfInternal._goalGroupIdByGoalKey :: any)
	_ReleaseTrackedMap(selfInternal, selfInternal._scratchBucketsByCellPackedKey :: any)
	_ReleaseTrackedArray(selfInternal, selfInternal._scratchCellPackedKeys :: any)
	_ReleaseTrackedArray(selfInternal, selfInternal._scratchFreeCellBuckets :: any)
	_ReleaseTrackedMap(selfInternal, selfInternal._snapshot :: any)

	return true, nil
end

return table.freeze(FlowFrameState)
