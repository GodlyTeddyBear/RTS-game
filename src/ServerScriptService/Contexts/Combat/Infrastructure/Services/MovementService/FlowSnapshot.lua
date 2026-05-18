--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CombatMovementConfig = require(ReplicatedStorage.Contexts.Combat.Config.CombatMovementConfig)
local ParallelQuery = require(ReplicatedStorage.Utilities.ParallelQuery)
local TableRecycler = require(ReplicatedStorage.Utilities.TableRecycler)
local FlowFrameState = require(script.Parent.FlowFrameState)
local MovementMath = require(script.Parent.Math.MovementMath)
local MovementTypes = require(script.Parent.Types)

type TFlowMovementState = MovementTypes.TFlowMovementState
type TFlowFrameStateBuildSnapshotParams = MovementTypes.TFlowFrameStateBuildSnapshotParams
type TFlowFrameStateHandle = MovementTypes.TFlowFrameStateHandle
type TFlowSeparationSolveSnapshot = MovementTypes.TFlowSeparationSolveSnapshot
type TFlowSeparationSolveRow = MovementTypes.TFlowSeparationSolveRow

local SharedMemoryAuthoring = ParallelQuery.SharedMemoryAuthoring
local ResultApplication = ParallelQuery.ResultApplication
local ValidationHelpers = ParallelQuery.ValidationHelpers

return function(MovementService: any)
	function MovementService:_BuildPackedWallKeys(): { number }
		local pathfinder, mapping = self:_ResolveFastFlowRuntime()
		if pathfinder == nil or mapping == nil then
			return {}
		end

		if self._flowWallKeyCachePathfinder == pathfinder and self._flowWallPackedKeys ~= nil then
			return self._flowWallPackedKeys
		end

		local walls = pathfinder._Walls
		local packedKeys = {}
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
		self._flowWallPackedKeys = packedKeys
		self._flowWallGridHalfSize = if type(walls) == "table" and type(walls._Size) == "number" then walls._Size else 0
		return packedKeys
	end

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

	function MovementService:_GetOrCreateFlowFrameState(): TFlowFrameStateHandle
		local frameState = self._flowFrameState
		if frameState ~= nil then
			return frameState
		end

		frameState = FlowFrameState.new(self:_GetOrCreateFlowFrameStateRecycler()) :: TFlowFrameStateHandle
		self._flowFrameState = frameState
		return frameState
	end

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

	function MovementService:_CreateFlowSeparationSharedMemory(snapshot: TFlowSeparationSolveSnapshot): SharedTable
		local builder = SharedMemoryAuthoring.CreateSnapshotBuilder()
		SharedMemoryAuthoring.SetArrayValues(builder, "GoalGroupId", snapshot.GoalGroupId)
		SharedMemoryAuthoring.SetArrayValues(builder, "NeighborStartIndex", snapshot.NeighborStartIndex)
		SharedMemoryAuthoring.SetArrayValues(builder, "NeighborCount", snapshot.NeighborCount)
		SharedMemoryAuthoring.SetArrayValues(builder, "NeighborEntityIndex", snapshot.NeighborEntityIndex)
		SharedMemoryAuthoring.SetArrayValues(builder, "FlatPositionX", snapshot.FlatPositionX)
		SharedMemoryAuthoring.SetArrayValues(builder, "FlatPositionY", snapshot.FlatPositionY)
		SharedMemoryAuthoring.SetArrayValues(builder, "Radius", snapshot.Radius)
		SharedMemoryAuthoring.SetArrayValues(builder, "FlowVelocityX", snapshot.FlowVelocityX)
		SharedMemoryAuthoring.SetArrayValues(builder, "FlowVelocityY", snapshot.FlowVelocityY)
		SharedMemoryAuthoring.SetArrayValues(builder, "PreviousVelocityX", snapshot.PreviousVelocityX)
		SharedMemoryAuthoring.SetArrayValues(builder, "PreviousVelocityY", snapshot.PreviousVelocityY)
		SharedMemoryAuthoring.SetArrayValues(builder, "WalkSpeed", snapshot.WalkSpeed)
		SharedMemoryAuthoring.SetArrayValues(builder, "VelAlpha", snapshot.VelAlpha)
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
		return SharedMemoryAuthoring.BuildSharedMemory(builder)
	end

	function MovementService:_ApplyFlowVelocityRows(
		snapshot: TFlowSeparationSolveSnapshot,
		rows: { TFlowSeparationSolveRow },
		velocityByEntity: { [number]: Vector2 }?
	): { [number]: Vector2 }
		local resolvedVelocityByEntity = if velocityByEntity ~= nil then velocityByEntity else {}
		table.clear(resolvedVelocityByEntity)

		ResultApplication.ApplyRows({
			Rows = rows,
			ValidateRow = function(row)
				local indexValidation =
					ValidationHelpers.RequireIndexFields(row, { "EntityIndex" }, #snapshot.EntityIds)
				if not indexValidation.IsValid then
					return indexValidation
				end

				return ValidationHelpers.RequireNumberFields(row, { "VelocityX", "VelocityY" })
			end,
			ResolveTarget = function(row)
				return snapshot.EntityIds[row.EntityIndex]
			end,
			ApplyRow = function(entityId, row)
				resolvedVelocityByEntity[entityId] = Vector2.new(row.VelocityX, row.VelocityY)
			end,
		})

		return resolvedVelocityByEntity
	end

	function MovementService:_ResolveFlowFrameState(
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
			local sampledDirection = self:_SampleFlowDirectionXZ(movementState, position)
			if sampledDirection ~= nil then
				flowDirectionXZ = sampledDirection
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

	function MovementService:_ResolveFlowSnapshotBuildParams(
		tickId: number,
		dt: number,
		wallPackedKeys: { number }
	): TFlowFrameStateBuildSnapshotParams?
		local _pathfinder, mapping = self:_ResolveFastFlowRuntime()
		if mapping == nil then
			return nil
		end

		local config = CombatMovementConfig.FLOW_SOFT_SEPARATION
		return {
			TickId = tickId,
			DeltaTime = dt,
			CellWidthStuds = mapping.CellWidthStuds,
			OriginX = mapping.OriginWorld.X,
			OriginY = mapping.OriginWorld.Z,
			GridHalfSize = mapping.GridHalfSize,
			WallGridHalfSize = if type(self._flowWallGridHalfSize) == "number"
				then self._flowWallGridHalfSize
				else mapping.GridHalfSize,
			WallPackedKeys = wallPackedKeys,
			KForce = if type(config.KForce) == "number" then config.KForce else 80,
			MinSeparationDistance = if type(config.MinSeparationDistance) == "number"
				then config.MinSeparationDistance
				else 1e-4,
			WallCollisionEnabled = config.WallCollisionEnabled == true,
			WallCollisionAxisClampEnabled = config.WallCollisionAxisClampEnabled ~= false,
			WallCollisionCornerClampEnabled = config.WallCollisionCornerClampEnabled ~= false,
			WallCollisionUseUnitRadiusPadding = config.WallCollisionUseUnitRadiusPadding == true,
			WallCollisionCellProbePaddingStuds = if type(config.WallCollisionCellProbePaddingStuds) == "number"
				then config.WallCollisionCellProbePaddingStuds
				else 0,
			WallCollisionVelocityEpsilon = if type(config.WallCollisionVelocityEpsilon) == "number"
				then config.WallCollisionVelocityEpsilon
				else 1e-4,
			ClumpTouchPaddingStuds = self:_GetFlowClumpTouchPaddingStuds(),
		}
	end

	function MovementService:_ResolveFlowTickId(services: any?): number
		if type(services) == "table" and type(services.TickId) == "number" then
			return services.TickId
		end
		return self._flowFrameSerial + 1
	end

	function MovementService:_ResolveFlowDeltaTime(services: any?): number
		local dt = if type(services) == "table" and type(services.DeltaTime) == "number"
			then services.DeltaTime
			else if type(services) == "table" and type(services.Dt) == "number" then services.Dt else 1 / 60
		if dt <= 0 then
			return 1 / 60
		end
		return dt
	end

	function MovementService:_BuildFlowDispatchSnapshot(
		tickId: number,
		dt: number
	): (TFlowSeparationSolveSnapshot?, { [number]: boolean }?, { [number]: string }?)
		table.clear(self._flowInvalidReasonByEntity)

		local frameState = self:_GetOrCreateFlowFrameState()
		frameState:Reset()

		local goalKeyByEntity = self._flowReusableGoalKeyByEntity :: { [number]: string }
		table.clear(goalKeyByEntity)

		-- Resolve all valid flow entities into the frame-state SoA
		for entity, movementState in self._movementByEntity do
			if movementState.Mode == "Flow" then
				local goalKey, _goalPosition, _goalWorldSample, position, flowDirectionXZ, walkSpeed, radius, previousVelocityXZ, isSettled =
					self:_ResolveFlowFrameState(entity, movementState)
				if goalKey == nil or position == nil or walkSpeed == nil or radius == nil then
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
			end
		end

		if frameState:GetEntityCount() == 0 then
			return nil, nil, nil
		end

		-- Build the final separation snapshot from the frame-state object
		local wallPackedKeys = self:_BuildPackedWallKeys()
		local snapshotParams = self:_ResolveFlowSnapshotBuildParams(tickId, dt, wallPackedKeys)
		if snapshotParams == nil then
			return nil, nil, nil
		end

		local snapshot, touchedSettledNeighborByEntity = frameState:BuildSeparationSnapshot(snapshotParams)
		return snapshot, touchedSettledNeighborByEntity, goalKeyByEntity
	end
end
