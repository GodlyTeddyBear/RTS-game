--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CombatMovementConfig = require(ReplicatedStorage.Contexts.Combat.Config.CombatMovementConfig)
local DebugConfig = require(ReplicatedStorage.Config.DebugConfig)
local DebugPlus = require(ReplicatedStorage.Utilities.DebugPlus)
local ParallelRunner = require(ReplicatedStorage.Utilities.ParallelRunner)
local TableRecycler = require(ReplicatedStorage.Utilities.TableRecycler)
local FlowFrameState = require(script.Parent.FlowFrameState)
local MovementMath = require(script.Parent.Math.MovementMath)
local MovementTypes = require(script.Parent.Types)
local Result = require(ReplicatedStorage.Utilities.Result)
local Errors = require(script.Parent.Parent.Parent.Parent.Errors)

type TFlowSchedulerServices = MovementTypes.TFlowSchedulerServices
type TFlowMovementState = MovementTypes.TFlowMovementState
type TFlowFrameStateHandle = MovementTypes.TFlowFrameStateHandle
type TFlowSeparationDispatchPayload = MovementTypes.TFlowSeparationDispatchPayload
type TFlowSeparationRunRequest = MovementTypes.TFlowSeparationRunRequest
type TFlowPublishedFrameState = MovementTypes.TFlowPublishedFrameState
type TFlowSeparationSolveSnapshot = MovementTypes.TFlowSeparationSolveSnapshot
type TFlowSeparationSolveRow = MovementTypes.TFlowSeparationSolveRow
type TMovementService = MovementTypes.TMovementService
type TTableRecyclerLike = MovementTypes.TTableRecyclerLike
type TSharedPacket = ParallelRunner.TSharedPacket

local ResultApplication = ParallelRunner.ResultApplication
local ValidationHelpers = ParallelRunner.ValidationHelpers
local MOVEMENT_PROFILING_ENABLED = DebugConfig.COMBAT_MOVEMENT_PROFILING
local BUILD_DISPATCH_SNAPSHOT_PROFILE_TAG = "Combat:MovementService:Flow:BuildDispatchSnapshot"
local CREATE_STATIC_SHARED_MEMORY_PROFILE_TAG = "Combat:MovementService:Flow:CreateStaticSharedMemory"
local CREATE_DYNAMIC_SHARED_MEMORY_PROFILE_TAG = "Combat:MovementService:Flow:CreateDynamicSharedMemory"
local APPLY_STATIC_SHARED_MEMORY_PROFILE_TAG = "Combat:MovementService:Flow:ApplyStaticSharedMemory"
local PREPARE_SHARED_PACKET_PROFILE_TAG = "Combat:MovementService:Flow:PrepareSharedPacket"
local PREPARE_RUN_REQUEST_PROFILE_TAG = "Combat:MovementService:Flow:PrepareRunRequest"
local APPLY_VELOCITY_ROWS_PROFILE_TAG = "Combat:MovementService:Flow:ApplyVelocityRows"
local Ok = Result.Ok
local Err = Result.Err

return function(MovementService: TMovementService)
	-- Builds the packed wall-key array used by the flow separation snapshot.
	function MovementService:_BuildPackedWallKeys(): { number }
		local packedKeys = self._flowWallPackedKeys
		if not packedKeys then
			packedKeys = {}
			self._flowWallPackedKeys = packedKeys
		end

		local pathfinder, mapping = self:_ResolveFastFlowRuntime()
		if not pathfinder or not mapping then
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

		if walls and type(walls._Grid) == "table" and type(walls._GetCellPos) == "function" then
			for index, value in walls._Grid do
				if value then
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
	function MovementService:_GetOrCreateFlowFrameStateRecycler(): TTableRecyclerLike
		local recycler = self._flowFrameStateRecycler
		if recycler then
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
		if frameState then
			return frameState
		end

		frameState = FlowFrameState.new(self:_GetOrCreateFlowFrameStateRecycler()) :: TFlowFrameStateHandle
		self._flowFrameState = frameState
		return frameState
	end

	-- Destroys the reusable flow frame-state handle and its recycler.
	function MovementService:_DestroyFlowFrameState()
		local frameState = self._flowFrameState :: TFlowFrameStateHandle?
		if frameState then
			local didDestroy, destroyError = frameState:Destroy()
			assert(didDestroy, destroyError)
		end
		self._flowFrameState = nil

		local recycler = self._flowFrameStateRecycler
		if recycler then
			local didDestroyRecycler, destroyRecyclerError = recycler:Destroy()
			assert(didDestroyRecycler, destroyRecyclerError)
		end
		self._flowFrameStateRecycler = nil
	end

	-- Builds the stable packet fields that can be reused across many flow dispatches.
	function MovementService:_CreateFlowSeparationStaticSharedMemory(
		snapshot: TFlowSeparationSolveSnapshot
	): TSharedPacket
		local closeCreateStaticSharedMemoryProfile =
			DebugPlus.begin(CREATE_STATIC_SHARED_MEMORY_PROFILE_TAG, MOVEMENT_PROFILING_ENABLED)
		local sharedMemory = {
			Arrays = {
				WallPackedKeys = snapshot.WallPackedKeys,
			},
			Scalars = {
				CellWidthStuds = snapshot.CellWidthStuds,
				OriginX = snapshot.OriginX,
				OriginY = snapshot.OriginY,
				WallGridHalfSize = snapshot.WallGridHalfSize,
				KForce = snapshot.KForce,
				MinSeparationDistance = snapshot.MinSeparationDistance,
				WallCollisionEnabled = snapshot.WallCollisionEnabled,
				WallCollisionAxisClampEnabled = snapshot.WallCollisionAxisClampEnabled,
				WallCollisionCornerClampEnabled = snapshot.WallCollisionCornerClampEnabled,
				WallCollisionUseUnitRadiusPadding = snapshot.WallCollisionUseUnitRadiusPadding,
				WallCollisionCellProbePaddingStuds = snapshot.WallCollisionCellProbePaddingStuds,
				WallCollisionVelocityEpsilon = snapshot.WallCollisionVelocityEpsilon,
				ClumpTouchPaddingStuds = snapshot.ClumpTouchPaddingStuds,
			},
		} :: TSharedPacket
		closeCreateStaticSharedMemoryProfile()
		return sharedMemory
	end

	-- Converts the per-tick flow separation snapshot into a dynamic SharedPlus packet for the parallel job.
	function MovementService:_CreateFlowSeparationDynamicSharedMemory(
		snapshot: TFlowSeparationSolveSnapshot
	): TSharedPacket
		local closeCreateDynamicSharedMemoryProfile =
			DebugPlus.begin(CREATE_DYNAMIC_SHARED_MEMORY_PROFILE_TAG, MOVEMENT_PROFILING_ENABLED)
		local sharedMemory = {
			Arrays = {
				GoalGroupId = snapshot.GoalGroupId,
				GoalGroupCellRecordStartIndex = snapshot.GoalGroupCellRecordStartIndex,
				GoalGroupCellRecordCount = snapshot.GoalGroupCellRecordCount,
				GoalGroupCellWidthStuds = snapshot.GoalGroupCellWidthStuds,
				GroupCellX = snapshot.GroupCellX,
				GroupCellY = snapshot.GroupCellY,
				CellPackedKey = snapshot.CellPackedKey,
				CellMemberStartIndex = snapshot.CellMemberStartIndex,
				CellMemberCount = snapshot.CellMemberCount,
				CellMemberEntityIndex = snapshot.CellMemberEntityIndex,
				FlatPositionX = snapshot.FlatPositionX,
				FlatPositionY = snapshot.FlatPositionY,
				Radius = snapshot.Radius,
				FlowVelocityX = snapshot.FlowVelocityX,
				FlowVelocityY = snapshot.FlowVelocityY,
				PreviousVelocityX = snapshot.PreviousVelocityX,
				PreviousVelocityY = snapshot.PreviousVelocityY,
				WalkSpeed = snapshot.WalkSpeed,
				VelAlpha = snapshot.VelAlpha,
				IsSettled = snapshot.IsSettled,
			},
			Scalars = {
				EntityCount = snapshot.EntityCount,
				DeltaTime = snapshot.DeltaTime,
			},
		} :: TSharedPacket
		closeCreateDynamicSharedMemoryProfile()
		return sharedMemory
	end

	function MovementService:_EnsureFlowSeparationStaticSharedMemory(snapshot: TFlowSeparationSolveSnapshot)
		local pathfinder = self._flowWallKeyCachePathfinder
		if pathfinder and self._flowStaticSharedMemoryPathfinder == pathfinder and self._flowStaticSharedMemory then
			return
		end

		DebugPlus.profile(APPLY_STATIC_SHARED_MEMORY_PROFILE_TAG, function()
			self._flowStaticSharedMemory = self:_CreateFlowSeparationStaticSharedMemory(snapshot)
			self._flowStaticSharedMemoryPathfinder = pathfinder
		end, MOVEMENT_PROFILING_ENABLED)
	end

	-- Builds the managed-job shared packet after the snapshot has already been packed.
	function MovementService:_CreateFlowSeparationSharedPacket(snapshot: TFlowSeparationSolveSnapshot): TSharedPacket
		local sharedPacket
		DebugPlus.profile(PREPARE_SHARED_PACKET_PROFILE_TAG, function()
			sharedPacket = self:_CreateFlowSeparationDynamicSharedMemory(snapshot)
		end, MOVEMENT_PROFILING_ENABLED)

		return sharedPacket
	end

	-- Builds the per-dispatch run request after the shared packet has been prepared.
	function MovementService:_CreateFlowSeparationRunRequest(
		snapshot: TFlowSeparationSolveSnapshot
	): TFlowSeparationRunRequest
		local runRequest
		DebugPlus.profile(PREPARE_RUN_REQUEST_PROFILE_TAG, function()
			runRequest = {
				Args = {
					TickId = snapshot.TickId,
				},
				LogicalWorkCount = #snapshot.EntityIds,
				BatchSize = self:_GetFlowSeparationParallelBatchSize(),
			} :: TFlowSeparationRunRequest
		end, MOVEMENT_PROFILING_ENABLED)

		return runRequest
	end

	-- Assembles the final managed-job payload once the staged packet and run request are ready.
	function MovementService:_AssembleFlowSeparationDispatchPayload(
		snapshot: TFlowSeparationSolveSnapshot,
		sharedPacket: TSharedPacket,
		runRequest: TFlowSeparationRunRequest
	): TFlowSeparationDispatchPayload
		return {
			Snapshot = snapshot,
			SharedPacket = sharedPacket,
			RunRequest = runRequest,
		} :: TFlowSeparationDispatchPayload
	end

	-- Converts solver rows back into entity-indexed velocity and settled-neighbor maps.
	function MovementService:_ApplyFlowVelocityRows(
		snapshot: TFlowSeparationSolveSnapshot,
		rows: { TFlowSeparationSolveRow },
		velocityByEntity: { [number]: Vector2 }?,
		touchedSettledNeighborByEntity: { [number]: boolean }?
	): ({ [number]: Vector2 }, { [number]: boolean })
		local closeApplyVelocityRowsProfile =
			DebugPlus.begin(APPLY_VELOCITY_ROWS_PROFILE_TAG, MOVEMENT_PROFILING_ENABLED)

		local resolvedVelocityByEntity = velocityByEntity or {}
		table.clear(resolvedVelocityByEntity)
		local resolvedTouchedSettledNeighborByEntity = touchedSettledNeighborByEntity or {}
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
	): Result.Result<MovementTypes.TFlowBuildFrameStatePayload>
		local pathState = self._enemyEntityFactory:GetPathState(entity)
		local goalPosition = pathState and pathState.GoalPosition or nil
		if not goalPosition then
			return Err("MissingGoalPosition", Errors.MOVEMENT_MISSING_GOAL_POSITION)
		end

		local handleGoalChangeResult = self:_HandleFlowGoalChange(entity, movementState, goalPosition)
		if not handleGoalChangeResult.success then
			return handleGoalChangeResult
		end

		local position = self:_GetEntityPosition(entity)
		if not position then
			return Err("MissingModelPosition", Errors.MOVEMENT_MISSING_MODEL_POSITION)
		end

		local flowDirectionXZ = Vector2.zero
		local isSettled = self._flowSettledByEntity[entity] == true
		if not isSettled then
			self:_TryClearLatchedInvalidCellEscape(entity, movementState, position)
			local sampledDirection = self:_SampleFlowDirectionXZ(movementState, position)
			if sampledDirection then
				flowDirectionXZ = sampledDirection
			else
				local repairResult = self:_RepairFlowDirectionXZ(entity, movementState, goalPosition, position)
				if not repairResult.success then
					return repairResult
				end
				local repairPayload = repairResult.value
				local repairedDirection = repairPayload.Direction
				local recoveryStatus = repairPayload.Status
				if recoveryStatus == "RetryLater" then
					if movementState.RecoveryMode ~= "EscapingInvalidCell" then
						return Ok({
							Skip = true,
						})
					end
				end
				if repairedDirection then
					flowDirectionXZ = repairedDirection
				end
			end
		end

		return Ok({
			GoalKey = movementState.GoalKey,
			GoalPosition = goalPosition,
			GoalWorldSample = movementState.GoalWorldSample,
			Position = position,
			FlowDirectionXZ = flowDirectionXZ,
			WalkSpeed = self:_ApplyCurrentMoveSpeed(entity),
			Radius = self:_GetFlowAgentRadiusStuds(entity),
			PreviousVelocityXZ = self._flowVelocityByEntity[entity] or Vector2.zero,
			IsSettled = isSettled,
		})
	end

	-- Resolves the solve tick id from the scheduler payload or advances the local serial.
	function MovementService:_ResolveFlowTickId(services: TFlowSchedulerServices?): number
		if type(services) == "table" and type(services.TickId) == "number" then
			return services.TickId
		end
		return self._flowFrameSerial + 1
	end

	-- Resolves the delta time from the scheduler payload, falling back to one frame.
	function MovementService:_ResolveFlowDeltaTime(services: TFlowSchedulerServices?): number
		local dt = (type(services) == "table" and type(services.DeltaTime) == "number" and services.DeltaTime)
			or (type(services) == "table" and type(services.Dt) == "number" and services.Dt)
			or (1 / 60)
		if dt <= 0 then
			return 1 / 60
		end
		return dt
	end

	-- Builds the separation snapshot and reusable published frame state for the current tick.
	function MovementService:_BuildFlowDispatchSnapshot(
		tickId: number,
		dt: number
	): (
		TFlowSeparationSolveSnapshot?,
		{ [number]: string }?,
		TFlowPublishedFrameState?
	)
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
					nil, nil, nil, nil, nil, nil, nil, nil, nil
				local frameStateResult = self:_ResolveFlowBuildFrameState(entity, movementState)
				if not frameStateResult.success then
					self._flowInvalidReasonByEntity[entity] = frameStateResult.type
					continue
				end
				local framePayload = frameStateResult.value
				if framePayload.Skip then
					continue
				end
				goalKey = framePayload.GoalKey
				_goalPosition = framePayload.GoalPosition
				_goalWorldSample = framePayload.GoalWorldSample
				position = framePayload.Position
				flowDirectionXZ = framePayload.FlowDirectionXZ
				walkSpeed = framePayload.WalkSpeed
				radius = framePayload.Radius
				previousVelocityXZ = framePayload.PreviousVelocityXZ
				isSettled = framePayload.IsSettled

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
		if not mapping then
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
