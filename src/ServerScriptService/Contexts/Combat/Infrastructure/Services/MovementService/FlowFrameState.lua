--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TableRecycler = require(ReplicatedStorage.Utilities.TableRecycler)
local FlowNeighborhoodMath = require(script.Parent.Math.FlowNeighborhoodMath)
local MovementMath = require(script.Parent.Math.MovementMath)
local MovementTypes = require(script.Parent.Types)

type TTableRecyclerHandle = TableRecycler.TTableRecyclerHandle
type TFlowFrameStateHandle = MovementTypes.TFlowFrameStateHandle
type TFlowSeparationSolveSnapshot = MovementTypes.TFlowSeparationSolveSnapshot
type TNamedArrayMap = { [string]: { any } }

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
	_defaultWallGrid: { boolean },
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

local _ENTITY_ARRAY_FIELD_NAMES = {
	"_entityIds",
	"_goalGroupId",
	"_flatPositionX",
	"_flatPositionY",
	"_radius",
	"_flowVelocityX",
	"_flowVelocityY",
	"_previousVelocityX",
	"_previousVelocityY",
	"_walkSpeed",
	"_velAlpha",
	"_isSettled",
}

local _SNAPSHOT_ARRAY_FIELD_NAMES = {
	"_snapshotEntityIds",
	"_snapshotGoalGroupId",
	"_snapshotGoalGroupCellRecordStartIndex",
	"_snapshotGoalGroupCellRecordCount",
	"_snapshotGoalGroupCellWidthStuds",
	"_snapshotGroupCellX",
	"_snapshotGroupCellY",
	"_snapshotCellPackedKey",
	"_snapshotCellMemberStartIndex",
	"_snapshotCellMemberCount",
	"_snapshotCellMemberEntityIndex",
	"_snapshotFlatPositionX",
	"_snapshotFlatPositionY",
	"_snapshotRadius",
	"_snapshotFlowVelocityX",
	"_snapshotFlowVelocityY",
	"_snapshotPreviousVelocityX",
	"_snapshotPreviousVelocityY",
	"_snapshotWalkSpeed",
	"_snapshotVelAlpha",
	"_snapshotIsSettled",
}

local _SNAPSHOT_FIELD_TO_STORAGE = {
	EntityIds = "_snapshotEntityIds",
	GoalGroupId = "_snapshotGoalGroupId",
	GoalGroupCellRecordStartIndex = "_snapshotGoalGroupCellRecordStartIndex",
	GoalGroupCellRecordCount = "_snapshotGoalGroupCellRecordCount",
	GoalGroupCellWidthStuds = "_snapshotGoalGroupCellWidthStuds",
	GroupCellX = "_snapshotGroupCellX",
	GroupCellY = "_snapshotGroupCellY",
	CellPackedKey = "_snapshotCellPackedKey",
	CellMemberStartIndex = "_snapshotCellMemberStartIndex",
	CellMemberCount = "_snapshotCellMemberCount",
	CellMemberEntityIndex = "_snapshotCellMemberEntityIndex",
	FlatPositionX = "_snapshotFlatPositionX",
	FlatPositionY = "_snapshotFlatPositionY",
	Radius = "_snapshotRadius",
	FlowVelocityX = "_snapshotFlowVelocityX",
	FlowVelocityY = "_snapshotFlowVelocityY",
	PreviousVelocityX = "_snapshotPreviousVelocityX",
	PreviousVelocityY = "_snapshotPreviousVelocityY",
	WalkSpeed = "_snapshotWalkSpeed",
	VelAlpha = "_snapshotVelAlpha",
	IsSettled = "_snapshotIsSettled",
}

local function _AcquireNamedArrays(recycler: TTableRecyclerHandle, fieldNames: { string }): TNamedArrayMap
	local namedArrays: TNamedArrayMap = {}
	for _, fieldName in ipairs(fieldNames) do
		namedArrays[fieldName] = _AcquireArray(recycler)
	end
	return namedArrays
end

local _DESTROY_EXTRA_ARRAY_RELEASE_FIELD_NAMES = {
	"_defaultWallGrid",
	"_activeGoalKeys",
	"_scratchCellPackedKeys",
	"_scratchFreeCellBuckets",
}

local function _BuildDestroyArrayReleaseFieldNames(): { string }
	local fieldNames = {}
	for _, fieldName in ipairs(_ENTITY_ARRAY_FIELD_NAMES) do
		fieldNames[#fieldNames + 1] = fieldName
	end
	for _, fieldName in ipairs(_SNAPSHOT_ARRAY_FIELD_NAMES) do
		fieldNames[#fieldNames + 1] = fieldName
	end
	for _, fieldName in ipairs(_DESTROY_EXTRA_ARRAY_RELEASE_FIELD_NAMES) do
		fieldNames[#fieldNames + 1] = fieldName
	end
	return fieldNames
end

local _DESTROY_ARRAY_RELEASE_FIELD_NAMES = _BuildDestroyArrayReleaseFieldNames()

local _DESTROY_MAP_RELEASE_FIELD_NAMES = {
	"_entityIndicesByGoalKey",
	"_goalGroupIdByGoalKey",
	"_scratchBucketsByCellPackedKey",
	"_snapshot",
}

local function _ReleaseArrayFieldsByName(self: TFlowFrameStateInternal, fieldNames: { string })
	local rawSelf = self :: any
	for _, fieldName in ipairs(fieldNames) do
		_ReleaseTrackedArray(self, rawSelf[fieldName] :: { any })
	end
end

local function _ReleaseMapFieldsByName(self: TFlowFrameStateInternal, fieldNames: { string })
	local rawSelf = self :: any
	for _, fieldName in ipairs(fieldNames) do
		_ReleaseTrackedMap(self, rawSelf[fieldName] :: { [any]: any })
	end
end

-- Clear per-entity packed arrays that are rebuilt every frame.
local function _ClearEntityBuffers(self: TFlowFrameStateInternal)
	table.clear(self._entityIds)
	table.clear(self._goalGroupId)
	table.clear(self._flatPositionX)
	table.clear(self._flatPositionY)
	table.clear(self._radius)
	table.clear(self._flowVelocityX)
	table.clear(self._flowVelocityY)
	table.clear(self._previousVelocityX)
	table.clear(self._previousVelocityY)
	table.clear(self._walkSpeed)
	table.clear(self._velAlpha)
	table.clear(self._isSettled)
end

-- Clear snapshot structure-of-arrays buffers before repacking them.
local function _ClearSnapshotBuffers(self: TFlowFrameStateInternal)
	table.clear(self._snapshotEntityIds)
	table.clear(self._snapshotGoalGroupId)
	table.clear(self._snapshotGoalGroupCellRecordStartIndex)
	table.clear(self._snapshotGoalGroupCellRecordCount)
	table.clear(self._snapshotGoalGroupCellWidthStuds)
	table.clear(self._snapshotGroupCellX)
	table.clear(self._snapshotGroupCellY)
	table.clear(self._snapshotCellPackedKey)
	table.clear(self._snapshotCellMemberStartIndex)
	table.clear(self._snapshotCellMemberCount)
	table.clear(self._snapshotCellMemberEntityIndex)
	table.clear(self._snapshotFlatPositionX)
	table.clear(self._snapshotFlatPositionY)
	table.clear(self._snapshotRadius)
	table.clear(self._snapshotFlowVelocityX)
	table.clear(self._snapshotFlowVelocityY)
	table.clear(self._snapshotPreviousVelocityX)
	table.clear(self._snapshotPreviousVelocityY)
	table.clear(self._snapshotWalkSpeed)
	table.clear(self._snapshotVelAlpha)
	table.clear(self._snapshotIsSettled)
end

-- Reuse a scratch bucket when grouping entities by cell during snapshot builds.
local function _AcquireScratchCellBucket(self: TFlowFrameStateInternal): { number }
	local freeBuckets = self._scratchFreeCellBuckets
	local bucket = freeBuckets[#freeBuckets]
	if bucket then
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
		if bucket then
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
		if entityIndices then
			table.clear(entityIndices)
			_ReleaseTrackedArray(self, entityIndices)
			self._entityIndicesByGoalKey[goalKey] = nil
		end
	end
end

-- Release the scratch arrays used while building the separation snapshot.
local function _ReleaseScratchBucketArrays(self: TFlowFrameStateInternal)
	for cellPackedKey, bucket in self._scratchBucketsByCellPackedKey do
		if bucket then
			table.clear(bucket)
			_ReleaseTrackedArray(self, bucket)
			self._scratchBucketsByCellPackedKey[cellPackedKey] = nil
		end
	end

	local scratchFreeCellBuckets = self._scratchFreeCellBuckets
	for index = #scratchFreeCellBuckets, 1, -1 do
		local bucket = scratchFreeCellBuckets[index]
		if bucket then
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
	snapshot.WallGridWidth = nil
	snapshot.WallGrid = nil
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
	local namedArrays = _AcquireNamedArrays(recycler, _ENTITY_ARRAY_FIELD_NAMES)
	local snapshotArrays = _AcquireNamedArrays(recycler, _SNAPSHOT_ARRAY_FIELD_NAMES)
	for fieldName, fieldArray in snapshotArrays do
		namedArrays[fieldName] = fieldArray
	end

	local defaultWallGrid = _AcquireArray(recycler) :: { boolean }
	local entityIndicesByGoalKey = _AcquireMap(recycler) :: { [string]: { number } }
	local activeGoalKeys = _AcquireArray(recycler) :: { string }
	local goalGroupIdByGoalKey = _AcquireMap(recycler) :: { [string]: number }
	local scratchBucketsByCellPackedKey = _AcquireMap(recycler) :: { [number]: { number } }
	local scratchCellPackedKeys = _AcquireArray(recycler) :: { number }
	local scratchFreeCellBuckets = _AcquireArray(recycler) :: { { number } }
	local snapshot = _AcquireMap(recycler) :: any

	snapshot.TickId = 0
	snapshot.EntityCount = 0
	for snapshotFieldName, storageFieldName in _SNAPSHOT_FIELD_TO_STORAGE do
		snapshot[snapshotFieldName] = namedArrays[storageFieldName :: string]
	end
	snapshot.DeltaTime = 0
	snapshot.CellWidthStuds = 0
	snapshot.OriginX = 0
	snapshot.OriginY = 0
	snapshot.WallGridHalfSize = 0
	snapshot.WallGridWidth = 0
	snapshot.WallGrid = defaultWallGrid
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
		_entityIds = namedArrays._entityIds :: { number },
		_goalGroupId = namedArrays._goalGroupId :: { number },
		_flatPositionX = namedArrays._flatPositionX :: { number },
		_flatPositionY = namedArrays._flatPositionY :: { number },
		_radius = namedArrays._radius :: { number },
		_flowVelocityX = namedArrays._flowVelocityX :: { number },
		_flowVelocityY = namedArrays._flowVelocityY :: { number },
		_previousVelocityX = namedArrays._previousVelocityX :: { number },
		_previousVelocityY = namedArrays._previousVelocityY :: { number },
		_walkSpeed = namedArrays._walkSpeed :: { number },
		_velAlpha = namedArrays._velAlpha :: { number },
		_isSettled = namedArrays._isSettled :: { boolean },
		_snapshotEntityIds = namedArrays._snapshotEntityIds :: { number },
		_snapshotGoalGroupId = namedArrays._snapshotGoalGroupId :: { number },
		_snapshotGoalGroupCellRecordStartIndex = namedArrays._snapshotGoalGroupCellRecordStartIndex :: { number },
		_snapshotGoalGroupCellRecordCount = namedArrays._snapshotGoalGroupCellRecordCount :: { number },
		_snapshotGoalGroupCellWidthStuds = namedArrays._snapshotGoalGroupCellWidthStuds :: { number },
		_snapshotGroupCellX = namedArrays._snapshotGroupCellX :: { number },
		_snapshotGroupCellY = namedArrays._snapshotGroupCellY :: { number },
		_snapshotCellPackedKey = namedArrays._snapshotCellPackedKey :: { number },
		_snapshotCellMemberStartIndex = namedArrays._snapshotCellMemberStartIndex :: { number },
		_snapshotCellMemberCount = namedArrays._snapshotCellMemberCount :: { number },
		_snapshotCellMemberEntityIndex = namedArrays._snapshotCellMemberEntityIndex :: { number },
		_snapshotFlatPositionX = namedArrays._snapshotFlatPositionX :: { number },
		_snapshotFlatPositionY = namedArrays._snapshotFlatPositionY :: { number },
		_snapshotRadius = namedArrays._snapshotRadius :: { number },
		_snapshotFlowVelocityX = namedArrays._snapshotFlowVelocityX :: { number },
		_snapshotFlowVelocityY = namedArrays._snapshotFlowVelocityY :: { number },
		_snapshotPreviousVelocityX = namedArrays._snapshotPreviousVelocityX :: { number },
		_snapshotPreviousVelocityY = namedArrays._snapshotPreviousVelocityY :: { number },
		_snapshotWalkSpeed = namedArrays._snapshotWalkSpeed :: { number },
		_snapshotVelAlpha = namedArrays._snapshotVelAlpha :: { number },
		_snapshotIsSettled = namedArrays._snapshotIsSettled :: { boolean },
		_snapshot = snapshot :: TFlowSeparationSolveSnapshot,
		_defaultWallGrid = defaultWallGrid,
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

	_ClearEntityBuffers(selfInternal)
	_ClearSnapshotBuffers(selfInternal)
	table.clear(selfInternal._goalGroupIdByGoalKey)

	for _, goalKey in ipairs(selfInternal._activeGoalKeys) do
		local entityIndices = selfInternal._entityIndicesByGoalKey[goalKey]
		if entityIndices then
			table.clear(entityIndices)
		end
	end

	table.clear(selfInternal._activeGoalKeys)
	_ResetScratchCellBuckets(selfInternal)
	selfInternal._snapshot.WallGrid = selfInternal._defaultWallGrid
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
	if existingGoalGroupId then
		return existingGoalGroupId
	end

	local nextGoalGroupId = selfInternal._nextGoalGroupId + 1
	selfInternal._nextGoalGroupId = nextGoalGroupId
	selfInternal._goalGroupIdByGoalKey[goalKey] = nextGoalGroupId

	local entityIndices = selfInternal._entityIndicesByGoalKey[goalKey]
	if not entityIndices then
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

	if entityIndices then
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
    @param wallGridWidth number -- Width of the wall grid used for direct index lookup.
    @param wallGrid { boolean } -- Dense 1-based wall occupancy array used by the solve.
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
	wallGridWidth: number,
	wallGrid: { boolean },
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
	_ClearSnapshotBuffers(selfInternal)

	-- Pack each goal group and bucket entities by separation cell within that group.
	for _, goalKey in ipairs(selfInternal._activeGoalKeys) do
		local entityIndices = selfInternal._entityIndicesByGoalKey[goalKey]
		if entityIndices and #entityIndices > 0 then
			local groupCellWidthStuds = FlowNeighborhoodMath.ResolveCellWidthForEntityIndices(self, entityIndices)
			local groupStartSnapshotEntityIndex = orderedEntityCount + 1

			_ResetScratchCellBuckets(selfInternal)

			for _, rawEntityIndex in ipairs(entityIndices) do
				orderedEntityCount += 1
				local cellPackedKey =
					_CopyRawEntityToSnapshot(selfInternal, orderedEntityCount, rawEntityIndex, groupCellWidthStuds)

				local cellBucket = selfInternal._scratchBucketsByCellPackedKey[cellPackedKey]
				if not cellBucket then
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
				if cellBucket then
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
	snapshot.WallGridWidth = wallGridWidth
	snapshot.WallGrid = wallGrid
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
	_ReleaseArrayFieldsByName(selfInternal, _DESTROY_ARRAY_RELEASE_FIELD_NAMES)
	_ReleaseMapFieldsByName(selfInternal, _DESTROY_MAP_RELEASE_FIELD_NAMES)

	return true, nil
end

return table.freeze(FlowFrameState)
