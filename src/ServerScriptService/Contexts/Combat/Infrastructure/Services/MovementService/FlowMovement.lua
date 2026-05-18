--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CombatMovementConfig = require(ReplicatedStorage.Contexts.Combat.Config.CombatMovementConfig)
local FastFlowHelper = require(ReplicatedStorage.Utilities.FastFlowHelper)
local ParallelQuery = require(ReplicatedStorage.Utilities.ParallelQuery)
local FlowMath = require(script.Parent.FlowMath)
local FlowNeighborhoodMath = require(script.Parent.FlowNeighborhoodMath)
local FlowSeparationMath = require(script.Parent.FlowSeparationMath)
local MovementMath = require(script.Parent.MovementMath)
local MovementTypes = require(script.Parent.Types)

type TFlowMovementState = MovementTypes.TFlowMovementState
type TFlowFrameInput = MovementTypes.TFlowFrameInput
type TFlowFrameSolution = MovementTypes.TFlowFrameSolution
type TFlowSeparationSolveSnapshot = MovementTypes.TFlowSeparationSolveSnapshot
type TFlowSeparationSolveRow = MovementTypes.TFlowSeparationSolveRow
type TManagedJob = MovementTypes.TManagedJob

local GOAL_POSITION_EPSILON = 0.01
local ManagedJobPolicies = ParallelQuery.ManagedJobPolicies
local ResultApplication = ParallelQuery.ResultApplication
local SharedMemoryAuthoring = ParallelQuery.SharedMemoryAuthoring
local ValidationHelpers = ParallelQuery.ValidationHelpers

return function(MovementService: any)
	function MovementService:_GetFlowConfig(): any
		return CombatMovementConfig.FLOW_SOFT_SEPARATION
	end

	function MovementService:_GetFlowVelocityAlpha(): number
		local config = self:_GetFlowConfig()
		local configured = if config ~= nil then config.VelAlpha else nil
		if type(configured) == "number" then
			return math.clamp(configured, 0, 1)
		end
		return 0.15
	end

	function MovementService:_GetFlowClumpRadiusStuds(): number
		local config = self:_GetFlowConfig()
		local configured = if config ~= nil then config.ClumpIdleRadiusStuds else nil
		if type(configured) == "number" and configured > 0 then
			return configured
		end
		return 8
	end

	function MovementService:_GetFlowClumpTouchPaddingStuds(): number
		local config = self:_GetFlowConfig()
		local configured = if config ~= nil then config.ClumpTouchDistancePaddingStuds else nil
		if type(configured) == "number" and configured >= 0 then
			return configured
		end
		return 0.5
	end

	function MovementService:_GetFlowVelocityParallelMinEntityCount(): number
		local config = self:_GetFlowConfig()
		local configured = if config ~= nil then config.ParallelMinVelocityEntityCount else nil
		if type(configured) == "number" and configured >= 0 then
			return math.floor(configured)
		end
		return 1
	end

	function MovementService:_GetFlowSeparationParallelActorCount(): number
		local config = self:_GetFlowConfig()
		local configured = if config ~= nil then config.ParallelActorCount else nil
		if type(configured) == "number" and configured > 0 then
			return math.floor(configured)
		end
		return 32
	end

	function MovementService:_GetFlowSeparationParallelBatchSize(): number
		local config = self:_GetFlowConfig()
		local configured = if config ~= nil then config.ParallelVelocityBatchSize else nil
		if type(configured) == "number" and configured > 0 then
			return math.floor(configured)
		end
		return 8
	end

	function MovementService:_GetFlowSeparationParallelTimeoutSeconds(): number
		local config = self:_GetFlowConfig()
		local configured = if config ~= nil then config.ParallelVelocityTimeoutSeconds else nil
		if type(configured) == "number" and configured > 0 then
			return configured
		end
		return 1
	end

	function MovementService:_GetFlowSeparationParallelMaxInFlightSeconds(): number
		local config = self:_GetFlowConfig()
		local configured = if config ~= nil then config.ParallelAsyncMaxInFlightSeconds else nil
		if type(configured) == "number" and configured > 0 then
			return configured
		end
		return 1
	end

	function MovementService:_IsFlowSeparationParallelEnabled(): boolean
		local config = self:_GetFlowConfig()
		return config ~= nil and config.Enabled == true and config.ParallelEnabled == true
	end

	function MovementService:_GetFlowAgentRadiusStuds(entity: number): number
		local agentParams = self:_GetAgentParams(entity)
		local radius = agentParams.AgentRadius
		if type(radius) == "number" and radius > 0 then
			return radius
		end
		return 2
	end

	function MovementService:_GetOrCreateFlowSeparationRunner(): any
		local runner = self._flowSeparationParallelRunner
		if runner ~= nil then
			return runner
		end

		runner = ParallelQuery.new({
			Name = "CombatFlowMovement",
			ActorCount = self:_GetFlowSeparationParallelActorCount(),
			Operations = {
				script.Parent.Parallel.FlowSeparationSolveOperation,
			},
		})
		self._flowSeparationParallelRunner = runner
		return runner
	end

	function MovementService:_CreateFlowSeparationManagedJob(): TManagedJob
		local runner = self:_GetOrCreateFlowSeparationRunner()
		return runner:CreateManagedJob({
			OperationName = "FlowSeparationSolve",
			BuildLocalMemory = function(snapshot: TFlowSeparationSolveSnapshot)
				return self:_CreateFlowSeparationSharedMemory(snapshot)
			end,
			BuildRunRequest = function(snapshot: TFlowSeparationSolveSnapshot)
				return {
					WorkCount = #snapshot.EntityIds,
					BatchSize = self:_GetFlowSeparationParallelBatchSize(),
					TimeoutSeconds = self:_GetFlowSeparationParallelTimeoutSeconds(),
				}
			end,
			GetSessionToken = function(_snapshot: TFlowSeparationSolveSnapshot)
				return self._flowCurrentSessionUserId
			end,
			MaxInFlightSeconds = self:_GetFlowSeparationParallelMaxInFlightSeconds(),
			Policy = ManagedJobPolicies.StrictFreshOnly,
		})
	end

	function MovementService:_GetOrCreateFlowSeparationManagedJob(): TManagedJob
		local job = self._flowSeparationManagedJob
		if job == nil then
			job = self:_CreateFlowSeparationManagedJob()
			self._flowSeparationManagedJob = job
		end
		return job
	end

	function MovementService:_DestroyFlowSeparationRunner()
		local runner = self._flowSeparationParallelRunner
		if runner ~= nil then
			runner:Destroy()
		end
		self._flowSeparationParallelRunner = nil
		self._flowSeparationManagedJob = nil
		self._flowLatestParallelSolve = nil
	end

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
		rows: { TFlowSeparationSolveRow }
	): { [number]: Vector2 }
		local velocityByEntity: { [number]: Vector2 } = {}

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
				velocityByEntity[entityId] = Vector2.new(row.VelocityX, row.VelocityY)
			end,
		})

		return velocityByEntity
	end

	function MovementService:_ConsumeCompletedFlowSeparationSolve()
		local job = self._flowSeparationManagedJob
		if job == nil then
			return
		end

		local status = job:GetStatus()
		if status.HasCompletedResult ~= true then
			return
		end

		local managedResult = job:PollCompleted(self._flowCurrentSessionUserId)
		if managedResult == nil or managedResult.Err ~= nil or managedResult.Rows == nil then
			return
		end

		local snapshot = managedResult.Payload :: TFlowSeparationSolveSnapshot
		self._flowLatestParallelSolve = {
			TickId = snapshot.TickId,
			VelocityByEntity = self:_ApplyFlowVelocityRows(snapshot, managedResult.Rows :: any),
		}
	end

	function MovementService:_TryDispatchFlowSeparationSolve(snapshot: TFlowSeparationSolveSnapshot)
		if not self:_IsFlowSeparationParallelEnabled() then
			return
		end
		if #snapshot.EntityIds < self:_GetFlowVelocityParallelMinEntityCount() then
			return
		end

		local job = self:_GetOrCreateFlowSeparationManagedJob()
		local status = job:GetStatus()
		if status.InFlight then
			return
		end

		pcall(function()
			job:Dispatch(snapshot)
		end)
	end

	function MovementService:_StartFlow(entity: number, goalPosition: Vector3): (boolean, string?)
		local goalKey, goalWorldSample, reason = self:_AttachEntityToFlowGoal(entity, goalPosition, false)
		if goalKey == nil or goalWorldSample == nil then
			return false, reason
		end

		self._movementByEntity[entity] = {
			Mode = "Flow",
			GoalSnapshot = goalPosition,
			GoalKey = goalKey,
			GoalWorldSample = goalWorldSample,
		}
		self:_RefreshActiveFlowGoalMembership(entity, nil)
		self._flowVelocityByEntity[entity] = Vector2.zero
		self:_GetEntityRootPart(entity)
		self:_GetHumanoid(entity)
		self._enemyEntityFactory:SetPathMoving(entity, true)
		return true, nil
	end

	function MovementService:_HandleFlowGoalChange(
		entity: number,
		movementState: TFlowMovementState,
		goalPosition: Vector3
	): (boolean, string?)
		if (goalPosition - movementState.GoalSnapshot).Magnitude <= GOAL_POSITION_EPSILON then
			return true, nil
		end

		local goalKey, goalWorldSample, reason = self:_AttachEntityToFlowGoal(entity, goalPosition, true)
		if goalKey == nil or goalWorldSample == nil then
			return false, reason or "FastFlowGenerateFailed"
		end

		movementState.GoalSnapshot = goalPosition
		movementState.GoalKey = goalKey
		movementState.GoalWorldSample = goalWorldSample
		self._flowVelocityByEntity[entity] = Vector2.zero
		return true, nil
	end

	function MovementService:_SampleFlowDirectionXZ(movementState: TFlowMovementState, position: Vector3): Vector2?
		local _pathfinder, mapping = self:_ResolveFastFlowRuntime()
		if mapping == nil then
			return nil
		end

		local sharedEntry = self:_GetSharedFlowfieldEntry(movementState.GoalKey)
		if sharedEntry == nil then
			return nil
		end

		local steering = sharedEntry.Flowfield:GetDirection(FastFlowHelper.WorldXZToGridCell(position, mapping))
		if steering == nil then
			return nil
		end
		return Vector2.new(steering.X, steering.Y)
	end

	function MovementService:_BuildFlowFrameInput(entity: number, goalGroupId: number): TFlowFrameInput?
		local movementState = self._movementByEntity[entity]
		if movementState == nil or movementState.Mode ~= "Flow" then
			return nil
		end

		local pathState = self._enemyEntityFactory:GetPathState(entity)
		local goalPosition = if pathState ~= nil then pathState.GoalPosition else nil
		if goalPosition == nil then
			self._flowInvalidReasonByEntity[entity] = "MissingGoalPosition"
			return nil
		end

		local handledGoalChange, reason = self:_HandleFlowGoalChange(entity, movementState, goalPosition)
		if not handledGoalChange then
			self._flowInvalidReasonByEntity[entity] = reason or "FastFlowGenerateFailed"
			return nil
		end

		local position = self:_GetEntityPosition(entity)
		if position == nil then
			self._flowInvalidReasonByEntity[entity] = "MissingModelPosition"
			return nil
		end

		local flowDirectionXZ = Vector2.zero
		if self._flowSettledByEntity[entity] ~= true then
			local sampledDirection = self:_SampleFlowDirectionXZ(movementState, position)
			if sampledDirection ~= nil then
				flowDirectionXZ = sampledDirection
			end
		end

		return {
			Entity = entity,
			GoalGroupId = goalGroupId,
			GoalKey = movementState.GoalKey,
			GoalPosition = goalPosition,
			GoalWorldSample = movementState.GoalWorldSample,
			Position = position,
			FlatPosition = MovementMath.FlatXZ(position),
			FlowDirectionXZ = flowDirectionXZ,
			WalkSpeed = self:_ApplyCurrentMoveSpeed(entity),
			Radius = self:_GetFlowAgentRadiusStuds(entity),
			PreviousVelocityXZ = self._flowVelocityByEntity[entity] or Vector2.zero,
			IsSettled = self._flowSettledByEntity[entity] == true,
		}
	end

	function MovementService:_BuildFlowSeparationSnapshot(
		tickId: number,
		dt: number,
		inputs: { TFlowFrameInput },
		inputsByGoalKey: { [string]: { TFlowFrameInput } }
	): (TFlowSeparationSolveSnapshot?, { [number]: boolean })
		local _pathfinder, mapping = self:_ResolveFastFlowRuntime()
		if mapping == nil then
			return nil, {}
		end

		local config = self:_GetFlowConfig()
		local wallPackedKeys = self:_BuildPackedWallKeys()
		local entityIndexByEntity: { [number]: number } = {}
		local touchedSettledNeighborByEntity: { [number]: boolean } = {}
		local snapshot: TFlowSeparationSolveSnapshot = {
			TickId = tickId,
			EntityIds = {},
			GoalGroupId = {},
			NeighborStartIndex = {},
			NeighborCount = {},
			NeighborEntityIndex = {},
			FlatPositionX = {},
			FlatPositionY = {},
			Radius = {},
			FlowVelocityX = {},
			FlowVelocityY = {},
			PreviousVelocityX = {},
			PreviousVelocityY = {},
			WalkSpeed = {},
			VelAlpha = {},
			DeltaTime = dt,
			CellWidthStuds = mapping.CellWidthStuds,
			OriginX = mapping.OriginWorld.X,
			OriginY = mapping.OriginWorld.Z,
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
		}

		for index, input in ipairs(inputs) do
			snapshot.EntityIds[index] = input.Entity
			snapshot.GoalGroupId[index] = input.GoalGroupId
			snapshot.FlatPositionX[index] = input.FlatPosition.X
			snapshot.FlatPositionY[index] = input.FlatPosition.Y
			snapshot.Radius[index] = input.Radius
			snapshot.FlowVelocityX[index] = input.FlowDirectionXZ.X * input.WalkSpeed
			snapshot.FlowVelocityY[index] = input.FlowDirectionXZ.Y * input.WalkSpeed
			snapshot.PreviousVelocityX[index] = input.PreviousVelocityXZ.X
			snapshot.PreviousVelocityY[index] = input.PreviousVelocityXZ.Y
			snapshot.WalkSpeed[index] = input.WalkSpeed
			snapshot.VelAlpha[index] = self:_GetFlowVelocityAlpha()
			entityIndexByEntity[input.Entity] = index
		end

		for _, goalInputs in inputsByGoalKey do
			local neighborBaseOffset = #snapshot.NeighborEntityIndex
			local touchedMap, neighborStartIndex, neighborCount, neighborEntityIndex =
				FlowNeighborhoodMath.BuildGoalNeighborhoodData(
					goalInputs,
					entityIndexByEntity,
					self:_GetFlowClumpTouchPaddingStuds()
				)

			for entityId, didTouch in touchedMap do
				if didTouch then
					touchedSettledNeighborByEntity[entityId] = true
				end
			end

			for entityIndex, startIndex in neighborStartIndex do
				snapshot.NeighborStartIndex[entityIndex] = neighborBaseOffset + startIndex
			end

			for entityIndex, count in neighborCount do
				snapshot.NeighborCount[entityIndex] = count
			end

			for _, otherEntityIndex in ipairs(neighborEntityIndex) do
				table.insert(snapshot.NeighborEntityIndex, otherEntityIndex)
			end
		end

		return snapshot, touchedSettledNeighborByEntity
	end

	function MovementService:_ResolveLocalVelocityMap(snapshot: TFlowSeparationSolveSnapshot): { [number]: Vector2 }
		local velocityByEntity: { [number]: Vector2 } = {}
		for entityIndex, entityId in ipairs(snapshot.EntityIds) do
			velocityByEntity[entityId] = FlowSeparationMath.ResolveVelocityWithWalls({
				EntityIndex = entityIndex,
				NeighborStartIndex = snapshot.NeighborStartIndex,
				NeighborCount = snapshot.NeighborCount,
				NeighborEntityIndex = snapshot.NeighborEntityIndex,
				FlatPositionX = snapshot.FlatPositionX,
				FlatPositionY = snapshot.FlatPositionY,
				Radius = snapshot.Radius,
				FlowVelocityX = snapshot.FlowVelocityX,
				FlowVelocityY = snapshot.FlowVelocityY,
				PreviousVelocityX = snapshot.PreviousVelocityX,
				PreviousVelocityY = snapshot.PreviousVelocityY,
				WalkSpeed = snapshot.WalkSpeed,
				VelAlpha = snapshot.VelAlpha,
				WallPackedKeys = snapshot.WallPackedKeys,
				DeltaTime = snapshot.DeltaTime,
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
			})
		end
		return velocityByEntity
	end

	function MovementService:_ResolveParallelVelocityMap(snapshot: TFlowSeparationSolveSnapshot): { [number]: Vector2 }?
		self:_ConsumeCompletedFlowSeparationSolve()
		local latestParallelSolve = self._flowLatestParallelSolve
		if latestParallelSolve == nil or latestParallelSolve.TickId ~= snapshot.TickId then
			return nil
		end
		return latestParallelSolve.VelocityByEntity
	end

	function MovementService:_BuildFlowSolutionForInput(
		input: TFlowFrameInput,
		finalVelocityXZ: Vector2,
		touchedSettledNeighbor: boolean
	): TFlowFrameSolution
		local arrivalRadius = FlowMath.ResolveArrivalRadius(input.GoalPosition, input.GoalWorldSample)
		if MovementMath.XZDistance(input.Position, input.GoalPosition) <= arrivalRadius then
			return {
				VelocityXZ = Vector2.zero,
				MoveTarget = nil,
				DidArrive = true,
				ShouldSettle = false,
				HasSteering = false,
			}
		end

		local mapping = self._fastFlowMapping
		local moveTarget = FlowMath.ComputeMoveTarget(
			input.Position,
			finalVelocityXZ,
			FlowMath.ResolveLookaheadDistanceStuds(
				input.WalkSpeed,
				if mapping ~= nil then mapping.CellWidthStuds else nil
			)
		)
		local isInsideClumpRadius = MovementMath.XZDistance(input.Position, input.GoalPosition)
			<= self:_GetFlowClumpRadiusStuds()

		return {
			VelocityXZ = finalVelocityXZ,
			MoveTarget = moveTarget,
			DidArrive = false,
			ShouldSettle = not input.IsSettled and isInsideClumpRadius and touchedSettledNeighbor,
			HasSteering = finalVelocityXZ.Magnitude > 0,
		}
	end

	function MovementService:_PrepareFlowSolutions(services: any?)
		local tickId = if type(services) == "table" and type(services.TickId) == "number"
			then services.TickId
			else self._flowFrameSerial + 1
		if self._flowPreparedTickId == tickId then
			return
		end

		self._flowPreparedTickId = tickId
		self._flowFrameSerial = tickId
		self._flowCurrentSessionUserId = self:_ResolveActiveSessionUserId()
		self._flowInvalidReasonByEntity = {}
		self._flowFrameInputsByEntity = {}
		self._flowFrameSolutionsByEntity = {}

		local dt = if type(services) == "table" and type(services.DeltaTime) == "number"
			then services.DeltaTime
			else if type(services) == "table" and type(services.Dt) == "number" then services.Dt else 1 / 60
		if dt <= 0 then
			dt = 1 / 60
		end

		local allInputs = {}
		local nextGoalGroupId = 0
		local inputsByGoalKey: { [string]: { TFlowFrameInput } } = {}
		local goalGroupIdByKey: { [string]: number } = {}
		for entity, movementState in self._movementByEntity do
			if movementState.Mode == "Flow" then
				local goalGroupId = goalGroupIdByKey[movementState.GoalKey]
				if goalGroupId == nil then
					nextGoalGroupId += 1
					goalGroupId = nextGoalGroupId
					goalGroupIdByKey[movementState.GoalKey] = goalGroupId
					inputsByGoalKey[movementState.GoalKey] = {}
				end

				local input = self:_BuildFlowFrameInput(entity, goalGroupId)
				if input ~= nil then
					self._flowFrameInputsByEntity[entity] = input
					table.insert(inputsByGoalKey[input.GoalKey], input)
					table.insert(allInputs, input)
				end
			end
		end

		if #allInputs == 0 then
			return
		end

		local snapshot, touchedSettledNeighborByEntity =
			self:_BuildFlowSeparationSnapshot(tickId, dt, allInputs, inputsByGoalKey)
		if snapshot == nil then
			return
		end

		local velocityByEntity = self:_ResolveParallelVelocityMap(snapshot)
		if velocityByEntity == nil then
			velocityByEntity = self:_ResolveLocalVelocityMap(snapshot)
			self:_TryDispatchFlowSeparationSolve(snapshot)
		end

		for _, input in ipairs(allInputs) do
			local velocityXZ = velocityByEntity[input.Entity] or Vector2.zero
			self._flowFrameSolutionsByEntity[input.Entity] =
				self:_BuildFlowSolutionForInput(input, velocityXZ, touchedSettledNeighborByEntity[input.Entity] == true)
		end
	end

	function MovementService:_StepFlowAdvance(
		entity: number,
		movementState: TFlowMovementState,
		services: any?
	): (boolean, string?)
		self:_PrepareFlowSolutions(services)

		local invalidReason = self._flowInvalidReasonByEntity[entity]
		if invalidReason ~= nil then
			self:StopMovement(entity)
			return false, invalidReason
		end

		local solution = self._flowFrameSolutionsByEntity[entity]
		if solution == nil then
			self:_StopHumanoid(entity)
			self._enemyEntityFactory:SetPathMoving(entity, false)
			return false, nil
		end

		if solution.DidArrive then
			self._flowVelocityByEntity[entity] = Vector2.zero
			self._flowSettledByEntity[entity] = nil
			self:_StopHumanoid(entity)
			self._enemyEntityFactory:SetPathMoving(entity, false)
			return true, nil
		end

		if solution.ShouldSettle then
			self._flowSettledByEntity[entity] = true
			self:_RefreshActiveFlowGoalMembership(entity, movementState.GoalKey)
		end

		self._flowVelocityByEntity[entity] = solution.VelocityXZ
		self:_IssueHumanoidMoveTo(entity, solution.MoveTarget, solution.VelocityXZ)
		self._enemyEntityFactory:SetPathMoving(entity, solution.MoveTarget ~= nil)
		return false, nil
	end
end
