--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local FastFlowHelper = require(ServerStorage.Utilities.FastFlowHelper)
local CombatMovementConfig = require(ReplicatedStorage.Contexts.Combat.Config.CombatMovementConfig)
local MovementTypes = require(script.Parent.Types)
local MovementMath = require(script.Parent.Math.MovementMath)
local Result = require(ReplicatedStorage.Utilities.Result)
local Errors = require(script.Parent.Parent.Parent.Parent.Errors)

type TFastFlowGridMapping = MovementTypes.TFastFlowGridMapping
type TFlowfieldLike = MovementTypes.TFlowfieldLike
type TMovementService = MovementTypes.TMovementService
type TFlowRepairResult = MovementTypes.TFlowRepairResult
type TSharedFlowfieldEntry = MovementTypes.TSharedFlowfieldEntry
type TFlowMovementState = MovementTypes.TFlowMovementState
type TFlowCellState = FastFlowHelper.TFlowCellState

local ESCAPE_TARGET_REACHED_EPSILON_STUDS = 0.75
local Ok = Result.Ok
local Err = Result.Err
local fromNilable = Result.fromNilable

return function(MovementService: TMovementService)
	-- Clears the latched recovery state when flow movement no longer needs an escape target.
	function MovementService:_ClearFlowRecoveryState(entity: number, movementState: TFlowMovementState?)
		self._flowRecoveredOpenCellByEntity[entity] = nil
		if movementState then
			movementState.RecoveryMoveTarget = nil
			movementState.RecoveryOpenCell = nil
			movementState.RecoveryMode = "None"
		end
	end

	-- Returns whether fast-flow visualization is enabled for this combat session.
	function MovementService:_IsFastFlowDebugEnabled(): boolean
		return CombatMovementConfig.FASTFLOW_VISUALIZATION.Enabled == true
			or CombatMovementConfig.FASTFLOW_ARROW_VISUALIZATION.Enabled == true
	end

	-- Resolves the fast-flow runtime pair and rejects unusable cache state.
	function MovementService:_ResolveFastFlowRuntime(): (MovementTypes.TFastFlowPathfinder?, TFastFlowGridMapping?)
		local mapping = self._fastFlowMapping
		local pathfinder = self._fastFlowPathfinder
		if not pathfinder or not mapping then
			return nil, nil
		end
		if mapping.CellWidthStuds <= 0 then
			return nil, nil
		end
		return pathfinder, mapping
	end

	-- Classifies the world position into fast-flow cell state and returns the runtime pair used for recovery.
	function MovementService:_ClassifyFlowCellState(position: Vector3): (
		TFlowCellState?,
		Vector2?,
		MovementTypes.TFastFlowPathfinder?,
		TFastFlowGridMapping?
	)
		local pathfinder, mapping = self:_ResolveFastFlowRuntime()
		if not pathfinder or not mapping then
			return nil, nil, nil, nil
		end

		local cellState, cell = FastFlowHelper.ClassifyWorldXZCell(pathfinder, position, mapping)
		return cellState :: TFlowCellState, cell, pathfinder, mapping
	end

	-- Returns whether a flow cell is blocked or outside the grid.
	function MovementService:_IsFlowCellStateInvalid(cellState: TFlowCellState?): boolean
		return cellState == "Blocked" or cellState == "OutOfBounds"
	end

	-- Returns whether the movement state is currently latched to an invalid-cell escape target.
	function MovementService:_HasLatchedInvalidCellEscape(movementState: TFlowMovementState): boolean
		return movementState.RecoveryMode == "EscapingInvalidCell"
			and movementState.RecoveryMoveTarget ~= nil
			and movementState.RecoveryOpenCell ~= nil
	end

	-- Sanitizes a move target so flow movement never asks the humanoid to step into a blocked cell.
	function MovementService:_SanitizeFlowMoveTarget(targetPosition: Vector3?): Vector3?
		if not targetPosition then
			return nil
		end

		local cellState, cell, pathfinder, mapping = self:_ClassifyFlowCellState(targetPosition)
		if not cellState or not cell or not pathfinder or not mapping then
			return targetPosition
		end
		if not self:_IsFlowCellStateInvalid(cellState :: TFlowCellState) then
			return targetPosition
		end

		local openCell = FastFlowHelper.FindNearestOpenCellDeep(pathfinder, cell, mapping)
		if not openCell then
			return nil
		end

		return FastFlowHelper.GridCellToWorldXZ(openCell, mapping, targetPosition.Y)
	end

	-- Latches an open-cell escape target so the entity can move out of an invalid cell safely.
	function MovementService:_SetLatchedInvalidCellEscape(
		entity: number,
		movementState: TFlowMovementState,
		openCell: Vector2,
		mapping: TFastFlowGridMapping,
		yLevel: number
	): Vector3
		local recoveryMoveTarget = FastFlowHelper.GridCellToWorldXZ(openCell, mapping, yLevel)
		self._flowRecoveredOpenCellByEntity[entity] = openCell
		movementState.RecoveryMoveTarget = recoveryMoveTarget
		movementState.RecoveryOpenCell = openCell
		movementState.RecoveryMode = "EscapingInvalidCell"
		return recoveryMoveTarget
	end

	-- Clears the latched escape when the entity reaches open space or the recovery target.
	function MovementService:_TryClearLatchedInvalidCellEscape(
		entity: number,
		movementState: TFlowMovementState,
		position: Vector3
	): boolean
		if movementState.RecoveryMode ~= "EscapingInvalidCell" then
			return false
		end

		local cellState = self:_ClassifyFlowCellState(position)
		local recoveryMoveTarget = movementState.RecoveryMoveTarget
		local reachedRecoveryTarget = recoveryMoveTarget
			and MovementMath.XZDistance(position, recoveryMoveTarget) <= ESCAPE_TARGET_REACHED_EPSILON_STUDS
		if cellState == "Open" or reachedRecoveryTarget then
			self:_ClearFlowRecoveryState(entity, movementState)
			return true
		end

		return false
	end

	-- Samples the flowfield direction for one cell without falling back to recovery heuristics.
	function MovementService:_SampleFlowDirectionFromCell(movementState: TFlowMovementState, cell: Vector2): Vector2?
		local sharedEntry = self:_GetSharedFlowfieldEntry(movementState.GoalKey)
		if not sharedEntry then
			return nil
		end

		local steering = sharedEntry.Flowfield:GetDirection(cell)
		if not steering then
			return nil
		end

		return Vector2.new(steering.X, steering.Y)
	end

	-- Rebuilds an escape direction from the nearest open cell when the current cell is invalid.
	function MovementService:_TryRecoverFlowDirectionFromOpenCell(
		entity: number,
		movementState: TFlowMovementState,
		position: Vector3,
		pathfinder: MovementTypes.TFastFlowPathfinder,
		mapping: TFastFlowGridMapping
	): Vector2?
		local openCell = FastFlowHelper.FindNearestOpenCellDeep(
			pathfinder,
			FastFlowHelper.WorldXZToGridCell(position, mapping),
			mapping
		)
		if not openCell then
			return nil
		end

		local openCellDirection = self:_SampleFlowDirectionFromCell(movementState, openCell)
		if not openCellDirection then
			return nil
		end

		self:_SetLatchedInvalidCellEscape(entity, movementState, openCell, mapping, position.Y)
		return openCellDirection
	end

	-- Resolves the goal cell and world sample used to attach an entity to a shared flowfield.
	function MovementService:_ResolveFlowGoal(goalPosition: Vector3): Result.Result<MovementTypes.TResolvedFlowGoal>
		local pathfinder, mapping = self:_ResolveFastFlowRuntime()
		if not pathfinder or not mapping then
			return Err("FastFlowNotConfigured", Errors.MOVEMENT_FLOW_NOT_CONFIGURED)
		end

		local goalCell = pathfinder:FindOpenCell(FastFlowHelper.WorldXZToGridCell(goalPosition, mapping))
		local goalCellResult = fromNilable(goalCell, "FastFlowGenerateFailed", Errors.MOVEMENT_FLOW_GENERATE_FAILED)
		if not goalCellResult.success then
			return goalCellResult
		end
		goalCell = goalCellResult.value

		local goalWorldSample = FastFlowHelper.GridCellToWorldXZ(goalCell :: Vector2, mapping, goalPosition.Y)
		return Ok({
			Pathfinder = pathfinder,
			Mapping = mapping,
			GoalCell = goalCell :: Vector2,
			GoalWorldSample = goalWorldSample,
		})
	end

	-- Collects representative starts so flowfield generation can prune work when allowed.
	function MovementService:_GetSharedRepresentativeStarts(goalKey: string): { Vector3 }?
		local config = CombatMovementConfig.FASTFLOW_SHARED_FIELDS
		if not config.UsePrunedGeneration then
			return nil
		end

		local starts = self._flowRepresentativeStarts :: { Vector3 }
		table.clear(starts)
		local maxStarts = math.max(1, math.floor(config.RepresentativeStartCap or 8))
		local activeEntities = self._activeFlowEntitiesByGoalKey[goalKey]
		if not activeEntities then
			return nil
		end

		for entityId in activeEntities do
			if #starts >= maxStarts then
				break
			end

			local movementState = self._movementByEntity[entityId]
			if movementState and movementState.Mode == "Flow" and not self._flowSettledByEntity[entityId] then
				local entityPosition = self:_GetEntityPosition(entityId)
				if entityPosition then
					table.insert(starts, entityPosition)
				end
			end
		end

		if #starts == 0 then
			return nil
		end

		return starts
	end

	-- Builds or refreshes the shared flowfield cache entry for one goal key.
	function MovementService:_CreateSharedFlowfield(
		goalKey: string,
		goalCell: Vector2,
		goalWorldSample: Vector3,
		forceUnpruned: boolean?
	): Result.Result<TSharedFlowfieldEntry>
		local pathfinder, mapping = self:_ResolveFastFlowRuntime()
		if not pathfinder or not mapping then
			return Err("FastFlowNotConfigured", Errors.MOVEMENT_FLOW_NOT_CONFIGURED)
		end

		local representativeStarts = (not forceUnpruned) and self:_GetSharedRepresentativeStarts(goalKey) or nil
		local flowfield =
			FastFlowHelper.GenerateFlowfieldWorld(pathfinder, goalWorldSample, mapping, representativeStarts)
		if not flowfield and representativeStarts then
			flowfield = FastFlowHelper.GenerateFlowfieldWorld(pathfinder, goalWorldSample, mapping, nil)
		end
		local flowfieldResult = fromNilable(flowfield, "FastFlowGenerateFailed", Errors.MOVEMENT_FLOW_GENERATE_FAILED)
		if not flowfieldResult.success then
			return flowfieldResult
		end
		flowfield = flowfieldResult.value

		local entry: TSharedFlowfieldEntry = {
			Flowfield = flowfield :: TFlowfieldLike,
			GoalCell = goalCell,
			GoalWorldSample = goalWorldSample,
			LastRefreshClock = os.clock(),
			RefreshInProgress = false,
			RefCount = 0,
		}
		self:_EmitFlowfieldDebug(flowfield :: TFlowfieldLike, goalWorldSample)
		return Ok(entry)
	end

	-- Resolves the shared flowfield cache entry and refreshes it when the caller requests it.
	function MovementService:_ResolveSharedFlowfield(
		goalPosition: Vector3,
		forceRefresh: boolean?,
		forceUnpruned: boolean?
	): Result.Result<MovementTypes.TResolvedSharedFlowfield>
		local goalResult = self:_ResolveFlowGoal(goalPosition)
		if not goalResult.success then
			return goalResult
		end
		local goal = goalResult.value
		local goalCell = goal.GoalCell
		local goalWorldSample = goal.GoalWorldSample

		local goalKey = MovementMath.FlowGoalKey(goalCell)
		local existingEntry = self._sharedFlowfieldsByGoalKey[goalKey]
		if existingEntry and not forceRefresh then
			return Ok({
				GoalKey = goalKey,
				GoalWorldSample = existingEntry.GoalWorldSample,
			})
		end

		local newEntryResult = self:_CreateSharedFlowfield(goalKey, goalCell, goalWorldSample, forceUnpruned)
		if not newEntryResult.success then
			return newEntryResult
		end
		local newEntry = newEntryResult.value

		if existingEntry then
			newEntry.RefCount = existingEntry.RefCount
		end
		self._sharedFlowfieldsByGoalKey[goalKey] = newEntry
		return Ok({
			GoalKey = goalKey,
			GoalWorldSample = newEntry.GoalWorldSample,
		})
	end

	-- Returns the cached shared flowfield entry for one goal key.
	function MovementService:_GetSharedFlowfieldEntry(goalKey: string?): TSharedFlowfieldEntry?
		if not goalKey then
			return nil
		end
		return self._sharedFlowfieldsByGoalKey[goalKey]
	end

	-- Decrements the shared flowfield reference count and evicts the entry when unused.
	function MovementService:_DetachSharedFlowfield(goalKey: string?)
		if not goalKey then
			return
		end

		local entry = self._sharedFlowfieldsByGoalKey[goalKey]
		if not entry then
			return
		end

		entry.RefCount = math.max(0, entry.RefCount - 1)
		if entry.RefCount == 0 then
			self._sharedFlowfieldsByGoalKey[goalKey] = nil
		end
	end

	-- Removes one entity from the active-member set for a shared flow goal.
	function MovementService:_RemoveEntityFromActiveFlowGoal(entity: number, goalKey: string?)
		if not goalKey then
			return
		end

		local activeEntities = self._activeFlowEntitiesByGoalKey[goalKey]
		if not activeEntities then
			return
		end

		activeEntities[entity] = nil
		if not next(activeEntities) then
			self._activeFlowEntitiesByGoalKey[goalKey] = nil
		end
	end

	-- Adds one entity to the active-member set for a shared flow goal.
	function MovementService:_AddEntityToActiveFlowGoal(entity: number, goalKey: string?)
		if not goalKey then
			return
		end

		local activeEntities = self._activeFlowEntitiesByGoalKey[goalKey]
		if not activeEntities then
			activeEntities = {}
			self._activeFlowEntitiesByGoalKey[goalKey] = activeEntities
		end

		activeEntities[entity] = true
	end

	-- Keeps the active-member set aligned with the entity's current flow membership state.
	function MovementService:_RefreshActiveFlowGoalMembership(entity: number, previousGoalKey: string?)
		local currentGoalKey = self._flowGoalKeyByEntity[entity]
		if previousGoalKey ~= currentGoalKey then
			self:_RemoveEntityFromActiveFlowGoal(entity, previousGoalKey)
		end

		local movementState = self._movementByEntity[entity]
		local isActiveFlowMember = movementState ~= nil
			and movementState.Mode == "Flow"
			and currentGoalKey
			and not self._flowSettledByEntity[entity]

		if isActiveFlowMember then
			self:_AddEntityToActiveFlowGoal(entity, currentGoalKey)
		else
			self:_RemoveEntityFromActiveFlowGoal(entity, currentGoalKey)
		end
	end

	-- Attaches one entity to the shared flowfield entry for the resolved goal key.
	function MovementService:_AttachEntityToSharedFlowfield(entity: number, goalKey: string)
		local currentGoalKey = self._flowGoalKeyByEntity[entity]
		if currentGoalKey == goalKey then
			return
		end

		self:_DetachSharedFlowfield(currentGoalKey)

		local entry = self._sharedFlowfieldsByGoalKey[goalKey]
		if entry then
			entry.RefCount += 1
		end
		self._flowGoalKeyByEntity[entity] = goalKey
		self:_RefreshActiveFlowGoalMembership(entity, currentGoalKey)
	end

	-- Resolves and attaches one entity to the shared flowfield for its goal position.
	function MovementService:_AttachEntityToFlowGoal(
		entity: number,
		goalPosition: Vector3,
		forceRefresh: boolean?,
		forceUnpruned: boolean?
	): Result.Result<MovementTypes.TResolvedSharedFlowfield>
		local flowGoalResult = self:_ResolveSharedFlowfield(goalPosition, forceRefresh, forceUnpruned)
		if not flowGoalResult.success then
			return flowGoalResult
		end
		local flowGoal = flowGoalResult.value
		local goalKey = flowGoal.GoalKey
		local goalWorldSample = flowGoal.GoalWorldSample

		self:_AttachEntityToSharedFlowfield(entity, goalKey)
		self._flowSettledByEntity[entity] = nil
		return Ok({
			GoalKey = goalKey,
			GoalWorldSample = goalWorldSample,
		})
	end

	-- Emits a debug visualization when flowfield debugging is enabled.
	function MovementService:_EmitFlowfieldDebug(flowfield: TFlowfieldLike, goalPosition: Vector3)
		local renderer = self._flowfieldDebugRenderer
		local _pathfinder, mapping = self:_ResolveFastFlowRuntime()
		if not renderer or not mapping or not self:_IsFastFlowDebugEnabled() then
			return
		end

		renderer(flowfield, mapping, goalPosition)
	end

	-- Repairs a flow direction by merging the live field or regenerating from the nearest open cell.
	function MovementService:_RepairFlowDirectionXZ(
		entity: number,
		movementState: TFlowMovementState,
		goalPosition: Vector3,
		position: Vector3
	): Result.Result<MovementTypes.TFlowRepairResult>
		-- First try to reuse the live field when the current cell is already open.
		local pathfinder, mapping = self:_ResolveFastFlowRuntime()
		local sharedEntry = self:_GetSharedFlowfieldEntry(movementState.GoalKey)
		if pathfinder and mapping and sharedEntry then
			local cellState = FastFlowHelper.ClassifyWorldXZCell(pathfinder, position, mapping)
			if cellState == "Open" then
				if movementState.RecoveryMode == "EscapingInvalidCell" then
					self:_ClearFlowRecoveryState(entity, movementState)
				end
				local mergedFlowfield =
					FastFlowHelper.MergeFlowfieldWorld(pathfinder, sharedEntry.Flowfield, position, mapping)
				if mergedFlowfield then
					sharedEntry.Flowfield = mergedFlowfield :: TFlowfieldLike
					sharedEntry.LastRefreshClock = os.clock()
					sharedEntry.RefreshInProgress = false
					self:_EmitFlowfieldDebug(mergedFlowfield :: TFlowfieldLike, sharedEntry.GoalWorldSample)

					local mergedDirection = self:_SampleFlowDirectionXZ(movementState, position)
					if mergedDirection then
						return Ok({
							Direction = mergedDirection,
							Status = "Recovered",
						} :: TFlowRepairResult)
					end
				end
			end

			-- Fall back to the nearest open cell when the live field cannot recover directly.
			local openCellDirection =
				self:_TryRecoverFlowDirectionFromOpenCell(entity, movementState, position, pathfinder, mapping)
			if openCellDirection then
				return Ok({
					Direction = openCellDirection,
					Status = "Recovered",
				} :: TFlowRepairResult)
			end
		end

		-- Regenerate the shared goal when neither the live field nor an open cell can recover the direction.
		local regeneratedGoal = self:_AttachEntityToFlowGoal(entity, goalPosition, true, true)
		if not regeneratedGoal.success then
			return Err("FastFlowRecoverFailed", Errors.MOVEMENT_FLOW_RECOVER_FAILED, {
				Entity = entity,
				GoalKey = movementState.GoalKey,
				CauseType = regeneratedGoal.type,
				CauseMessage = regeneratedGoal.message,
			})
		end
		local goalKey = regeneratedGoal.value.GoalKey
		local goalWorldSample = regeneratedGoal.value.GoalWorldSample

		movementState.GoalSnapshot = goalPosition
		movementState.GoalKey = goalKey
		movementState.GoalWorldSample = goalWorldSample

		-- Try the regenerated field first, then fall back to an open-cell escape if needed.
		local regeneratedDirection = self:_SampleFlowDirectionXZ(movementState, position)
		if regeneratedDirection then
			return Ok({
				Direction = regeneratedDirection,
				Status = "Recovered",
			} :: TFlowRepairResult)
		end

		if pathfinder and mapping then
			local openCellDirection =
				self:_TryRecoverFlowDirectionFromOpenCell(entity, movementState, position, pathfinder, mapping)
			if openCellDirection then
				return Ok({
					Direction = openCellDirection,
					Status = "Recovered",
				} :: TFlowRepairResult)
			end
		end

		return Ok({
			Direction = nil,
			Status = "RetryLater",
		} :: TFlowRepairResult)
	end
end
