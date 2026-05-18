--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CombatMovementConfig = require(ReplicatedStorage.Contexts.Combat.Config.CombatMovementConfig)
local ParallelQuery = require(ReplicatedStorage.Utilities.ParallelQuery)
local FlowNeighborhoodMath = require(script.Parent.Math.FlowNeighborhoodMath)
local MovementMath = require(script.Parent.Math.MovementMath)
local MovementTypes = require(script.Parent.Types)

type TFlowMovementState = MovementTypes.TFlowMovementState
type TFlowFrameInput = MovementTypes.TFlowFrameInput
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

	function MovementService:_BuildFlowFrameInput(entity: number, goalGroupId: number): TFlowFrameInput?
		local movementState = self._movementByEntity[entity] :: TFlowMovementState?
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
	): (TFlowSeparationSolveSnapshot?, { [number]: boolean }, { [number]: string })
		local _pathfinder, mapping = self:_ResolveFastFlowRuntime()
		if mapping == nil then
			return nil, {}, {}
		end

		local config = CombatMovementConfig.FLOW_SOFT_SEPARATION
		local wallPackedKeys = self:_BuildPackedWallKeys()
		local entityIndexByEntity: { [number]: number } = {}
		local touchedSettledNeighborByEntity: { [number]: boolean } = {}
		local goalKeyByEntity: { [number]: string } = {}
		local snapshot: TFlowSeparationSolveSnapshot = {
			TickId = tickId,
			EntityCount = #inputs,
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
			goalKeyByEntity[input.Entity] = input.GoalKey
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

		return snapshot, touchedSettledNeighborByEntity, goalKeyByEntity
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
		self._flowInvalidReasonByEntity = {}

		local allInputs = {}
		local inputsByGoalKey: { [string]: { TFlowFrameInput } } = {}
		local goalGroupIdByKey: { [string]: number } = {}
		local nextGoalGroupId = 0

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
					table.insert(inputsByGoalKey[input.GoalKey], input)
					table.insert(allInputs, input)
				end
			end
		end

		if #allInputs == 0 then
			return nil, nil, nil
		end

		return self:_BuildFlowSeparationSnapshot(tickId, dt, allInputs, inputsByGoalKey)
	end
end
