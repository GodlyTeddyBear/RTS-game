--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CombatMovementConfig = require(ReplicatedStorage.Contexts.Combat.Config.CombatMovementConfig)
local DebugConfig = require(ReplicatedStorage.Config.DebugConfig)
local DebugPlus = require(ReplicatedStorage.Utilities.DebugPlus)
local ParallelRunner = require(ReplicatedStorage.Utilities.ParallelRunner)
local ParallelQuery = require(ReplicatedStorage.Utilities.ParallelQuery)
local TableRecycler = require(ReplicatedStorage.Utilities.TableRecycler)
local FlowFrameState = require(script.Parent.FlowFrameState)
local MovementMath = require(script.Parent.Math.MovementMath)
local MovementTypes = require(script.Parent.Types)

type TFlowMovementState = MovementTypes.TFlowMovementState
type TFlowFrameStateHandle = MovementTypes.TFlowFrameStateHandle
type TFlowPublishedFrameState = MovementTypes.TFlowPublishedFrameState
type TFlowSeparationSolveSnapshot = MovementTypes.TFlowSeparationSolveSnapshot
type TFlowSeparationSolveRow = MovementTypes.TFlowSeparationSolveRow

local SharedMemoryAuthoring = ParallelQuery.SharedMemoryAuthoring
local ResultApplication = ParallelRunner.ResultApplication
local ValidationHelpers = ParallelRunner.ValidationHelpers
local MOVEMENT_PROFILING_ENABLED = DebugConfig.COMBAT_MOVEMENT_PROFILING
local BUILD_DISPATCH_SNAPSHOT_PROFILE_TAG = "Combat:MovementService:Flow:BuildDispatchSnapshot"
local CREATE_SHARED_MEMORY_PROFILE_TAG = "Combat:MovementService:Flow:CreateSharedMemory"
local APPLY_VELOCITY_ROWS_PROFILE_TAG = "Combat:MovementService:Flow:ApplyVelocityRows"

return function(MovementService: any)
	-- Builds the packed wall-key array used by the flow separation snapshot.
	function MovementService:_BuildPackedWallKeys(): { number }
		local packedKeys = self._flowWallPackedKeys
		if packedKeys == nil then
			packedKeys = {}
			self._flowWallPackedKeys = packedKeys
		end

		local pathfinder, mapping = self:_ResolveFastFlowRuntime()
		if pathfinder == nil or mapping == nil then
			table.clear(packedKeys)
			self._flowWallKeyCachePathfinder = nil
			self._flowWallGridHalfSize = 0
			return packedKeys
		end

		if self._flowWallKeyCachePathfinder == pathfinder then
			return packedKeys
		end

		local walls = pathfinder._Walls
		table.clear(packedKeys)

		if walls ~= nil and type(walls._Grid) == "table" and type(walls._GetCellPos) == "function" then
			for index, value in walls._Grid do
				if value == true then
					local cell = walls:_GetCellPos(index)
					table.insert(packedKeys, MovementMath.PackWallKey(cell.X, cell.Y))
				end
			end
		end

		table.sort(packedKeys)
		self._flowWallKeyCachePathfinder = pathfinder
		self._flowWallGridHalfSize = if type(walls) == "table" and type(walls._Size) == "number" then walls._Size else 0
		return packedKeys
	end

	-- Lazily creates the recycler used by flow frame-state snapshots.
	function MovementService:_GetOrCreateFlowFrameStateRecycler(): any
		local recycler = self._flowFrameStateRecycler
		if recycler ~= nil then
			return recycler
		end

		recycler = TableRecycler.new({
			Strict = true,
			DebugName = "CombatMovement.FlowFrameState",
		})
		self._flowFrameStateRecycler = recycler
		return recycler
	end

	-- Lazily creates the reusable flow frame-state handle.
	function MovementService:_GetOrCreateFlowFrameState(): TFlowFrameStateHandle
		local frameState = self._flowFrameState
		if frameState ~= nil then
			return frameState
		end

		frameState = FlowFrameState.new(self:_GetOrCreateFlowFrameStateRecycler()) :: TFlowFrameStateHandle
		self._flowFrameState = frameState
		return frameState
	end

	-- Destroys the reusable flow frame-state handle and its recycler.
	function MovementService:_DestroyFlowFrameState()
		local frameState = self._flowFrameState :: TFlowFrameStateHandle?
		if frameState ~= nil then
			local didDestroy, destroyError = frameState:Destroy()
			assert(didDestroy, destroyError)
		end
		self._flowFrameState = nil

		local recycler = self._flowFrameStateRecycler
		if recycler ~= nil then
			local didDestroyRecycler, destroyRecyclerError = recycler:Destroy()
			assert(didDestroyRecycler, destroyRecyclerError)
		end
		self._flowFrameStateRecycler = nil
	end

	-- Authoring converts the flow separation snapshot into shared memory for the parallel job.
	function MovementService:_CreateFlowSeparationSharedMemory(snapshot: TFlowSeparationSolveSnapshot): SharedTable
		local closeCreateSharedMemoryProfile =
			DebugPlus.begin(CREATE_SHARED_MEMORY_PROFILE_TAG, MOVEMENT_PROFILING_ENABLED)
		local builder = SharedMemoryAuthoring.CreateSnapshotBuilder()
		SharedMemoryAuthoring.SetArrayValues(builder, "GoalGroupId", snapshot.GoalGroupId)
		SharedMemoryAuthoring.SetArrayValues(
			builder,
			"GoalGroupCellRecordStartIndex",
			snapshot.GoalGroupCellRecordStartIndex
		)
		SharedMemoryAuthoring.SetArrayValues(
			builder,
			"GoalGroupCellRecordCount",
			snapshot.GoalGroupCellRecordCount
		)
		SharedMemoryAuthoring.SetArrayValues(
			builder,
			"GoalGroupCellWidthStuds",
			snapshot.GoalGroupCellWidthStuds
		)
		SharedMemoryAuthoring.SetArrayValues(builder, "GroupCellX", snapshot.GroupCellX)
		SharedMemoryAuthoring.SetArrayValues(builder, "GroupCellY", snapshot.GroupCellY)
		SharedMemoryAuthoring.SetArrayValues(builder, "CellPackedKey", snapshot.CellPackedKey)
		SharedMemoryAuthoring.SetArrayValues(builder, "CellMemberStartIndex", snapshot.CellMemberStartIndex)
		SharedMemoryAuthoring.SetArrayValues(builder, "CellMemberCount", snapshot.CellMemberCount)
		SharedMemoryAuthoring.SetArrayValues(builder, "CellMemberEntityIndex", snapshot.CellMemberEntityIndex)
		SharedMemoryAuthoring.SetArrayValues(builder, "FlatPositionX", snapshot.FlatPositionX)
		SharedMemoryAuthoring.SetArrayValues(builder, "FlatPositionY", snapshot.FlatPositionY)
		SharedMemoryAuthoring.SetArrayValues(builder, "Radius", snapshot.Radius)
		SharedMemoryAuthoring.SetArrayValues(builder, "FlowVelocityX", snapshot.FlowVelocityX)
		SharedMemoryAuthoring.SetArrayValues(builder, "FlowVelocityY", snapshot.FlowVelocityY)
		SharedMemoryAuthoring.SetArrayValues(builder, "PreviousVelocityX", snapshot.PreviousVelocityX)
		SharedMemoryAuthoring.SetArrayValues(builder, "PreviousVelocityY", snapshot.PreviousVelocityY)
		SharedMemoryAuthoring.SetArrayValues(builder, "WalkSpeed", snapshot.WalkSpeed)
		SharedMemoryAuthoring.SetArrayValues(builder, "VelAlpha", snapshot.VelAlpha)
		SharedMemoryAuthoring.SetArrayValues(builder, "IsSettled", snapshot.IsSettled)
		SharedMemoryAuthoring.SetArrayValues(builder, "WallPackedKeys", snapshot.WallPackedKeys)
		SharedMemoryAuthoring.SetScalar(builder, "EntityCount", snapshot.EntityCount)
		SharedMemoryAuthoring.SetScalar(builder, "DeltaTime", snapshot.DeltaTime)
		SharedMemoryAuthoring.SetScalar(builder, "CellWidthStuds", snapshot.CellWidthStuds)
		SharedMemoryAuthoring.SetScalar(builder, "OriginX", snapshot.OriginX)
		SharedMemoryAuthoring.SetScalar(builder, "OriginY", snapshot.OriginY)
		SharedMemoryAuthoring.SetScalar(builder, "WallGridHalfSize", snapshot.WallGridHalfSize)
		SharedMemoryAuthoring.SetScalar(builder, "KForce", snapshot.KForce)
		SharedMemoryAuthoring.SetScalar(builder, "MinSeparationDistance", snapshot.MinSeparationDistance)
		SharedMemoryAuthoring.SetScalar(builder, "WallCollisionEnabled", snapshot.WallCollisionEnabled)
		SharedMemoryAuthoring.SetScalar(
			builder,
			"WallCollisionAxisClampEnabled",
			snapshot.WallCollisionAxisClampEnabled
		)
		SharedMemoryAuthoring.SetScalar(
			builder,
			"WallCollisionCornerClampEnabled",
			snapshot.WallCollisionCornerClampEnabled
		)
		SharedMemoryAuthoring.SetScalar(
			builder,
			"WallCollisionUseUnitRadiusPadding",
			snapshot.WallCollisionUseUnitRadiusPadding
		)
		SharedMemoryAuthoring.SetScalar(
			builder,
			"WallCollisionCellProbePaddingStuds",
			snapshot.WallCollisionCellProbePaddingStuds
		)
		SharedMemoryAuthoring.SetScalar(builder, "WallCollisionVelocityEpsilon", snapshot.WallCollisionVelocityEpsilon)
		SharedMemoryAuthoring.SetScalar(builder, "ClumpTouchPaddingStuds", snapshot.ClumpTouchPaddingStuds)
		local sharedMemory = SharedMemoryAuthoring.BuildSharedMemory(builder)
		closeCreateSharedMemoryProfile()
		return sharedMemory
	end

	-- Converts solver rows back into entity-indexed velocity and settled-neighbor maps.
	function MovementService:_ApplyFlowVelocityRows(
		snapshot: TFlowSeparationSolveSnapshot,
		rows: { TFlowSeparationSolveRow },
		velocityByEntity: { [number]: Vector2 }?,
		touchedSettledNeighborByEntity: { [number]: boolean }?
	): ({ [number]: Vector2 }, { [number]: boolean })
		local closeApplyVelocityRowsProfile = DebugPlus.begin(APPLY_VELOCITY_ROWS_PROFILE_TAG, MOVEMENT_PROFILING_ENABLED)
		local resolvedVelocityByEntity = if velocityByEntity ~= nil then velocityByEntity else {}
		table.clear(resolvedVelocityByEntity)
		local resolvedTouchedSettledNeighborByEntity = if touchedSettledNeighborByEntity ~= nil
			then touchedSettledNeighborByEntity
			else {}
		table.clear(resolvedTouchedSettledNeighborByEntity)

		ResultApplication.ApplyRows({
			Rows = rows,
			ValidateRow = function(row)
				local indexValidation =
					ValidationHelpers.RequireIndexFields(row, { "EntityIndex" }, #snapshot.EntityIds)
				if not indexValidation.IsValid then
					return indexValidation
				end

				local numberValidation = ValidationHelpers.RequireNumberFields(row, { "VelocityX", "VelocityY" })
				if not numberValidation.IsValid then
					return numberValidation
				end
				if type(row.TouchedSettledNeighbor) ~= "boolean" then
					return {
						IsValid = false,
						FieldName = "TouchedSettledNeighbor",
						Reason = "ExpectedBoolean",
					}
				end
				return numberValidation
			end,
			ResolveTarget = function(row)
				return snapshot.EntityIds[row.EntityIndex]
			end,
			ApplyRow = function(entityId, row)
				resolvedVelocityByEntity[entityId] = Vector2.new(row.VelocityX, row.VelocityY)
				if row.TouchedSettledNeighbor then
					resolvedTouchedSettledNeighborByEntity[entityId] = true
				end
			end,
		})

		closeApplyVelocityRowsProfile()
		return resolvedVelocityByEntity, resolvedTouchedSettledNeighborByEntity
	end

	-- Resolves the frame inputs needed to build the dispatch snapshot for one flow entity.
	function MovementService:_ResolveFlowBuildFrameState(
		entity: number,
		movementState: TFlowMovementState
	): (string?, Vector3?, Vector3?, Vector3?, Vector2, number?, number?, Vector2, boolean)
		local pathState = self._enemyEntityFactory:GetPathState(entity)
		local goalPosition = if pathState ~= nil then pathState.GoalPosition else nil
		if goalPosition == nil then
			self._flowInvalidReasonByEntity[entity] = "MissingGoalPosition"
			return nil, nil, nil, nil, Vector2.zero, nil, nil, Vector2.zero, false
		end

		local handledGoalChange, reason = self:_HandleFlowGoalChange(entity, movementState, goalPosition)
		if not handledGoalChange then
			self._flowInvalidReasonByEntity[entity] = reason or "FastFlowGenerateFailed"
			return nil, nil, nil, nil, Vector2.zero, nil, nil, Vector2.zero, false
		end

		local position = self:_GetEntityPosition(entity)
		if position == nil then
			self._flowInvalidReasonByEntity[entity] = "MissingModelPosition"
			return nil, nil, nil, nil, Vector2.zero, nil, nil, Vector2.zero, false
		end

		local flowDirectionXZ = Vector2.zero
		local isSettled = self._flowSettledByEntity[entity] == true
		if not isSettled then
			self:_TryClearLatchedInvalidCellEscape(entity, movementState, position)
			local sampledDirection = self:_SampleFlowDirectionXZ(movementState, position)
			if sampledDirection ~= nil then
				flowDirectionXZ = sampledDirection
			else
				local repairedDirection, recoveryStatus, recoveryReason =
					self:_RepairFlowDirectionXZ(entity, movementState, goalPosition, position)
				if recoveryStatus == "Fatal" then
					self._flowInvalidReasonByEntity[entity] = recoveryReason or "FastFlowGenerateFailed"
					return nil, nil, nil, nil, Vector2.zero, nil, nil, Vector2.zero, false
				end
				if recoveryStatus == "RetryLater" then
					if movementState.RecoveryMode ~= "EscapingInvalidCell" then
						return nil, nil, nil, nil, Vector2.zero, nil, nil, Vector2.zero, false
					end
				end
				if repairedDirection ~= nil then
					flowDirectionXZ = repairedDirection
				end
			end
		end

		return
			movementState.GoalKey,
			goalPosition,
			movementState.GoalWorldSample,
			position,
			flowDirectionXZ,
			self:_ApplyCurrentMoveSpeed(entity),
			self:_GetFlowAgentRadiusStuds(entity),
			self._flowVelocityByEntity[entity] or Vector2.zero,
			isSettled
	end

	-- Resolves the solve tick id from the scheduler payload or advances the local serial.
	function MovementService:_ResolveFlowTickId(services: any?): number
		if type(services) == "table" and type(services.TickId) == "number" then
			return services.TickId
		end
		return self._flowFrameSerial + 1
	end

	-- Resolves the delta time from the scheduler payload, falling back to one frame.
	function MovementService:_ResolveFlowDeltaTime(services: any?): number
		local dt = if type(services) == "table" and type(services.DeltaTime) == "number"
			then services.DeltaTime
			else if type(services) == "table" and type(services.Dt) == "number" then services.Dt else 1 / 60
		if dt <= 0 then
			return 1 / 60
		end
		return dt
	end

	-- Builds the separation snapshot and reusable published frame state for the current tick.
	function MovementService:_BuildFlowDispatchSnapshot(
		tickId: number,
		dt: number
	): (TFlowSeparationSolveSnapshot?, { [number]: string }?, TFlowPublishedFrameState?)
		local closeBuildDispatchSnapshotProfile =
			DebugPlus.begin(BUILD_DISPATCH_SNAPSHOT_PROFILE_TAG, MOVEMENT_PROFILING_ENABLED)
		table.clear(self._flowInvalidReasonByEntity)

		local frameState = self:_GetOrCreateFlowFrameState()
		frameState:Reset()

		local goalKeyByEntity = self._flowReusableGoalKeyByEntity :: { [number]: string }
		table.clear(goalKeyByEntity)
		local goalPositionByEntity = self._flowReusableGoalPositionByEntity :: { [number]: Vector3 }
		local goalWorldSampleByEntity = self._flowReusableGoalWorldSampleByEntity :: { [number]: Vector3 }
		local positionByEntity = self._flowReusablePositionByEntity :: { [number]: Vector3 }
		local walkSpeedByEntity = self._flowReusableWalkSpeedByEntity :: { [number]: number }
		local isSettledByEntity = self._flowReusableIsSettledByEntity :: { [number]: boolean }
		table.clear(goalPositionByEntity)
		table.clear(goalWorldSampleByEntity)
		table.clear(positionByEntity)
		table.clear(walkSpeedByEntity)
		table.clear(isSettledByEntity)

		-- Resolve all valid flow entities into the frame-state SoA
		for entity, movementState in self._movementByEntity do
			if movementState.Mode == "Flow" then
				local goalKey, _goalPosition, _goalWorldSample, position, flowDirectionXZ, walkSpeed, radius, previousVelocityXZ, isSettled =
					self:_ResolveFlowBuildFrameState(entity, movementState)
				if
					goalKey == nil
					or _goalPosition == nil
					or _goalWorldSample == nil
					or position == nil
					or walkSpeed == nil
					or radius == nil
				then
					continue
				end

				local entityIndex = frameState:AddEntity(
					goalKey,
					entity,
					position,
					flowDirectionXZ,
					walkSpeed,
					radius,
					previousVelocityXZ,
					isSettled
				)
				frameState:SetVelAlpha(entityIndex, self:_GetFlowVelocityAlpha())
				goalKeyByEntity[entity] = goalKey
				goalPositionByEntity[entity] = _goalPosition
				goalWorldSampleByEntity[entity] = _goalWorldSample
				positionByEntity[entity] = position
				walkSpeedByEntity[entity] = walkSpeed
				if isSettled then
					isSettledByEntity[entity] = true
				end
			end
		end

		if frameState:GetEntityCount() == 0 then
			closeBuildDispatchSnapshotProfile()
			return nil, nil, nil
		end

		-- Build the final separation snapshot from the frame-state object
		local _pathfinder, mapping = self:_ResolveFastFlowRuntime()
		if mapping == nil then
			closeBuildDispatchSnapshotProfile()
			return nil, nil, nil
		end

		local wallPackedKeys = self:_BuildPackedWallKeys()
		local config = CombatMovementConfig.FLOW_SOFT_SEPARATION
		local snapshot = frameState:BuildSeparationSnapshot(
			tickId,
			dt,
			mapping.CellWidthStuds,
			mapping.OriginWorld.X,
			mapping.OriginWorld.Z,
			if type(self._flowWallGridHalfSize) == "number" then self._flowWallGridHalfSize else mapping.GridHalfSize,
			wallPackedKeys,
			if type(config.KForce) == "number" then config.KForce else 80,
			if type(config.MinSeparationDistance) == "number" then config.MinSeparationDistance else 1e-4,
			config.WallCollisionEnabled == true,
			config.WallCollisionAxisClampEnabled ~= false,
			config.WallCollisionCornerClampEnabled ~= false,
			config.WallCollisionUseUnitRadiusPadding == true,
			if type(config.WallCollisionCellProbePaddingStuds) == "number"
				then config.WallCollisionCellProbePaddingStuds
				else 0,
			if type(config.WallCollisionVelocityEpsilon) == "number" then config.WallCollisionVelocityEpsilon else 1e-4,
			self:_GetFlowClumpTouchPaddingStuds()
		)
		closeBuildDispatchSnapshotProfile()
		return snapshot, goalKeyByEntity, self._flowReusableFrameState :: TFlowPublishedFrameState
	end
end
