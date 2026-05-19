--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CombatMovementConfig = require(ReplicatedStorage.Contexts.Combat.Config.CombatMovementConfig)
local FastFlowHelper = require(ReplicatedStorage.Utilities.FastFlowHelper)
local FlowMath = require(script.Parent.Math.FlowMath)
local MovementMath = require(script.Parent.Math.MovementMath)
local MovementTypes = require(script.Parent.Types)

type TFlowMovementState = MovementTypes.TFlowMovementState
type TFlowPublishedFrameState = MovementTypes.TFlowPublishedFrameState
type TFlowPublishedSolve = MovementTypes.TFlowPublishedSolve

local GOAL_POSITION_EPSILON = 0.01
local STALL_VELOCITY_EPSILON = 0.05

return function(MovementService: any)
	-- Returns the shared flow configuration table used by all flow movement helpers.
	function MovementService:_GetFlowConfig(): any
		return CombatMovementConfig.FLOW_SOFT_SEPARATION
	end

	-- Returns the flow velocity alpha used to blend current and previous separation results.
	function MovementService:_GetFlowVelocityAlpha(): number
		local config = self:_GetFlowConfig()
		local configured = if config ~= nil then config.VelAlpha else nil
		if type(configured) == "number" then
			return math.clamp(configured, 0, 1)
		end
		return 0.15
	end

	-- Returns the idle clump radius used to detect when flow agents should settle together.
	function MovementService:_GetFlowClumpRadiusStuds(): number
		local config = self:_GetFlowConfig()
		local configured = if config ~= nil then config.ClumpIdleRadiusStuds else nil
		if type(configured) == "number" and configured > 0 then
			return configured
		end
		return 8
	end

	-- Returns the padding used when deciding whether a settled neighbor was touched.
	function MovementService:_GetFlowClumpTouchPaddingStuds(): number
		local config = self:_GetFlowConfig()
		local configured = if config ~= nil then config.ClumpTouchDistancePaddingStuds else nil
		if type(configured) == "number" and configured >= 0 then
			return configured
		end
		return 0.5
	end

	-- Returns the agent radius used by flow movement for one entity.
	function MovementService:_GetFlowAgentRadiusStuds(entity: number): number
		local agentParams = self:_GetAgentParams(entity)
		local radius = agentParams.AgentRadius
		if type(radius) == "number" and radius > 0 then
			return radius
		end
		return 2
	end

	-- Starts flow movement for one entity and initializes its flow runtime state.
	function MovementService:_StartFlow(entity: number, goalPosition: Vector3): (boolean, string?)
		-- Attach the entity to the shared flow goal before writing any runtime state.
		local goalKey, goalWorldSample, reason = self:_AttachEntityToFlowGoal(entity, goalPosition, false, false)
		if goalKey == nil or goalWorldSample == nil then
			return false, reason
		end

		-- Store the initial flow snapshot so later goal changes can detect real movement.
		local movementState: TFlowMovementState = {
			Mode = "Flow",
			GoalSnapshot = goalPosition,
			GoalKey = goalKey,
			GoalWorldSample = goalWorldSample,
			RecoveryMoveTarget = nil,
			RecoveryOpenCell = nil,
			RecoveryMode = "None",
		}
		self._movementByEntity[entity] = movementState
		self:_RefreshActiveFlowGoalMembership(entity, nil)
		self._flowVelocityByEntity[entity] = Vector2.zero

		-- Prime actor references and capture an escape target if the entity spawned in a bad cell.
		local rootPart = self:_GetEntityRootPart(entity)
		self:_GetHumanoid(entity)
		if rootPart ~= nil then
			local cellState, _, pathfinder, mapping = self:_ClassifyFlowCellState(rootPart.Position)
			if self:_IsFlowCellStateInvalid(cellState) and pathfinder ~= nil and mapping ~= nil then
				local openCell = FastFlowHelper.FindNearestOpenCellDeep(
					pathfinder,
					FastFlowHelper.WorldXZToGridCell(rootPart.Position, mapping),
					mapping
				)
				if openCell ~= nil then
					self:_SetLatchedInvalidCellEscape(
						entity,
						movementState,
						openCell,
						mapping,
						rootPart.Position.Y
					)
				end
			end
		end

		-- Mark the entity as path-moving only after the runtime state is fully initialized.
		self._enemyEntityFactory:SetPathMoving(entity, true)
		return true, nil
	end

	-- Updates the stored flow goal when the target position changes.
	function MovementService:_HandleFlowGoalChange(
		entity: number,
		movementState: TFlowMovementState,
		goalPosition: Vector3
	): (boolean, string?)
		if (goalPosition - movementState.GoalSnapshot).Magnitude <= GOAL_POSITION_EPSILON then
			return true, nil
		end

		local goalKey, goalWorldSample, reason = self:_AttachEntityToFlowGoal(entity, goalPosition, true, false)
		if goalKey == nil or goalWorldSample == nil then
			return false, reason or "FastFlowGenerateFailed"
		end

		movementState.GoalSnapshot = goalPosition
		movementState.GoalKey = goalKey
		movementState.GoalWorldSample = goalWorldSample
		self:_ClearFlowRecoveryState(entity, movementState)
		self._flowVelocityByEntity[entity] = Vector2.zero
		return true, nil
	end

	-- Samples the current flowfield direction for one entity.
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

	-- Builds the final movement solution inputs from the resolved flow direction and arrival state.
	function MovementService:_BuildFlowSolutionForInput(
		goalPosition: Vector3,
		goalWorldSample: Vector3,
		position: Vector3,
		walkSpeed: number,
		isSettled: boolean,
		finalVelocityXZ: Vector2,
		touchedSettledNeighbor: boolean
	): (Vector2, Vector3?, boolean, boolean, boolean)
		local arrivalRadius = FlowMath.ResolveArrivalRadius(goalPosition, goalWorldSample)
		if MovementMath.XZDistance(position, goalPosition) <= arrivalRadius then
			return Vector2.zero, nil, true, false, false
		end

		local mapping = self._fastFlowMapping
		local moveTarget = FlowMath.ComputeMoveTarget(
			position,
			finalVelocityXZ,
			FlowMath.ResolveLookaheadDistanceStuds(
				walkSpeed,
				if mapping ~= nil then mapping.CellWidthStuds else nil
			)
		)
		local isInsideClumpRadius = MovementMath.XZDistance(position, goalPosition)
			<= self:_GetFlowClumpRadiusStuds()

		return
			finalVelocityXZ,
			moveTarget,
			false,
			not isSettled and isInsideClumpRadius and touchedSettledNeighbor,
			finalVelocityXZ.Magnitude > 0
	end

	-- Detects whether the entity has stalled before it reaches its goal.
	function MovementService:_IsFlowAdvanceStalled(
		goalPosition: Vector3,
		goalWorldSample: Vector3,
		position: Vector3,
		velocityXZ: Vector2,
		moveTarget: Vector3?
	): boolean
		local arrivalRadius = FlowMath.ResolveArrivalRadius(goalPosition, goalWorldSample)
		if MovementMath.XZDistance(position, goalPosition) <= arrivalRadius then
			return false
		end

		if moveTarget ~= nil then
			return false
		end

		return velocityXZ.Magnitude <= STALL_VELOCITY_EPSILON
	end

	-- Detects whether the entity must recover because it is still inside an invalid flow cell.
	function MovementService:_ShouldForceFlowCellRecovery(
		goalPosition: Vector3,
		goalWorldSample: Vector3,
		position: Vector3
	): boolean
		local arrivalRadius = FlowMath.ResolveArrivalRadius(goalPosition, goalWorldSample)
		if MovementMath.XZDistance(position, goalPosition) <= arrivalRadius then
			return false
		end

		local cellState = self:_ClassifyFlowCellState(position)
		return self:_IsFlowCellStateInvalid(cellState)
	end

	-- Rebuilds flow inputs after recovery from a blocked or invalid cell.
	function MovementService:_BuildRecoveredFlowAdvanceInput(
		entity: number,
		movementState: TFlowMovementState,
		goalPosition: Vector3,
		position: Vector3,
		walkSpeed: number
	): (Vector2?, Vector3?, "Recovered" | "RetryLater" | "Fatal", string?)
		local repairedDirection, recoveryStatus, recoveryReason =
			self:_RepairFlowDirectionXZ(entity, movementState, goalPosition, position)
		if recoveryStatus ~= "Recovered" or repairedDirection == nil then
			return nil, nil, recoveryStatus, recoveryReason
		end

		local recoveredVelocityXZ = repairedDirection * walkSpeed
		local recoveryMoveTarget = movementState.RecoveryMoveTarget
		if recoveryMoveTarget ~= nil then
			return recoveredVelocityXZ, recoveryMoveTarget, "Recovered", nil
		end

		local mapping = self._fastFlowMapping
		local moveTarget = FlowMath.ComputeMoveTarget(
			position,
			recoveredVelocityXZ,
			FlowMath.ResolveLookaheadDistanceStuds(
				walkSpeed,
				if mapping ~= nil then mapping.CellWidthStuds else nil
			)
		)
		return recoveredVelocityXZ, moveTarget, "Recovered", nil
	end

	-- Continues the latched invalid-cell escape without waiting for a new solve.
	function MovementService:_TryContinueLatchedEscapeWithoutSolve(
		entity: number,
		movementState: TFlowMovementState,
		_reason: string
	): boolean
		if not self:_HasLatchedInvalidCellEscape(movementState) then
			return false
		end

		local position = self:_GetEntityPosition(entity)
		if position == nil then
			return false
		end

		if self:_TryClearLatchedInvalidCellEscape(entity, movementState, position) then
			return false
		end

		local recoveryMoveTarget = movementState.RecoveryMoveTarget
		if recoveryMoveTarget == nil then
			return false
		end

		local walkSpeed = self:_ApplyCurrentMoveSpeed(entity)
		local flatDelta = Vector2.new(recoveryMoveTarget.X - position.X, recoveryMoveTarget.Z - position.Z)
		local velocityXZ = if flatDelta.Magnitude > 0 then flatDelta.Unit * walkSpeed else Vector2.zero
		local sanitizedTarget = self:_SanitizeFlowMoveTarget(recoveryMoveTarget)
		self._flowVelocityByEntity[entity] = velocityXZ
		self:_IssueHumanoidMoveTo(entity, sanitizedTarget, velocityXZ)
		self._enemyEntityFactory:SetPathMoving(entity, sanitizedTarget ~= nil)
		return true
	end

	-- Repairs shared-flow membership when the current goal key no longer matches the snapshot.
	function MovementService:_TryRepairFlowGoalMembership(entity: number, movementState: TFlowMovementState): (boolean, string?)
		local goalKey, goalWorldSample, reason = self:_AttachEntityToFlowGoal(entity, movementState.GoalSnapshot, false, false)
		if goalKey == nil or goalWorldSample == nil then
			return false, if reason ~= nil then reason else "FastFlowGenerateFailed"
		end

		movementState.GoalKey = goalKey
		movementState.GoalWorldSample = goalWorldSample
		return true, nil
	end

	-- Advances one entity through the flow pipeline and applies the solved movement output.
	function MovementService:_StepFlowAdvance(
		entity: number,
		movementState: TFlowMovementState,
		services: any?
	): (boolean, string?)
		-- Update or dispatch the shared flow pipeline before reading any published outputs.
		self:_AdvanceFlowPipeline(services)

		-- Stop immediately when the pipeline has already marked the entity invalid.
		local invalidReason = self._flowInvalidReasonByEntity[entity]
		if invalidReason ~= nil then
			self:StopMovement(entity)
			return false, invalidReason
		end

		-- If no solve is available yet, keep any latched escape moving and retry next tick.
		local latestParallelSolve = self._flowLatestParallelSolve :: TFlowPublishedSolve?
		if latestParallelSolve == nil then
			if self:_TryContinueLatchedEscapeWithoutSolve(entity, movementState, "MissingLatestParallelSolve") then
				return false, nil
			end
			return false, nil
		end

		-- Read the published frame-state inputs for the current entity.
		local frameState = self._flowPublishedFrameState :: TFlowPublishedFrameState?
		if frameState == nil then
			if self:_TryContinueLatchedEscapeWithoutSolve(entity, movementState, "MissingPublishedFrameState") then
				return false, nil
			end
			return false, nil
		end

		-- Reject stale solve data when the published goal no longer matches the cached flow goal.
		local goalKey = frameState.GoalKeyByEntity[entity]
		local publishedGoalKey = latestParallelSolve.GoalKeyByEntity[entity]
		if goalKey == nil or publishedGoalKey == nil or publishedGoalKey ~= goalKey then
			if self:_TryContinueLatchedEscapeWithoutSolve(entity, movementState, "GoalKeyMismatch") then
				return false, nil
			end
			local repairedMembership, repairedReason = self:_TryRepairFlowGoalMembership(entity, movementState)
			if repairedMembership then
				return false, nil
			end
			return false, repairedReason
		end

		-- Collect the published movement inputs that were built during the dispatch snapshot.
		local goalPosition = frameState.GoalPositionByEntity[entity]
		local goalWorldSample = frameState.GoalWorldSampleByEntity[entity]
		local position = frameState.PositionByEntity[entity]
		local walkSpeed = frameState.WalkSpeedByEntity[entity]
		if goalPosition == nil or goalWorldSample == nil or position == nil or walkSpeed == nil then
			if self:_TryContinueLatchedEscapeWithoutSolve(entity, movementState, "MissingPublishedFlowInputs") then
				return false, nil
			end
			return false, nil
		end

		self:_TryClearLatchedInvalidCellEscape(entity, movementState, position)

		-- Read the solved flow velocity for the current entity from the latest parallel result.
		local velocityXZ = latestParallelSolve.VelocityByEntity[entity]
		if velocityXZ == nil then
			if self:_TryContinueLatchedEscapeWithoutSolve(entity, movementState, "MissingPublishedVelocity") then
				return false, nil
			end
			return false, nil
		end

		-- Convert the published inputs into the final humanoid movement command.
		local solvedVelocityXZ, moveTarget, didArrive, shouldSettle, _hasSteering = self:_BuildFlowSolutionForInput(
			goalPosition,
			goalWorldSample,
			position,
			walkSpeed,
			frameState.IsSettledByEntity[entity] == true,
			velocityXZ,
			latestParallelSolve.TouchedSettledNeighborByEntity[entity] == true
		)

		if movementState.RecoveryMode == "EscapingInvalidCell" then
			shouldSettle = false
		end

		-- Preserve the recovery target when one is already latched for the entity.
		if movementState.RecoveryMoveTarget ~= nil then
			moveTarget = movementState.RecoveryMoveTarget
		end
		moveTarget = self:_SanitizeFlowMoveTarget(moveTarget)

		-- Clear movement when the entity has arrived at the goal.
		if didArrive then
			self._flowVelocityByEntity[entity] = Vector2.zero
			self._flowSettledByEntity[entity] = nil
			self:_ClearFlowRecoveryState(entity, movementState)
			self:_StopHumanoid(entity)
			self._enemyEntityFactory:SetPathMoving(entity, false)
			return true, nil
		end

		-- Rebuild velocity when the entity stalls or remains in an invalid cell.
		local mustRecoverInvalidCell = self:_ShouldForceFlowCellRecovery(goalPosition, goalWorldSample, position)
		local isStalled = self:_IsFlowAdvanceStalled(goalPosition, goalWorldSample, position, solvedVelocityXZ, moveTarget)
		if mustRecoverInvalidCell or isStalled then
			if frameState.IsSettledByEntity[entity] == true then
				self._flowSettledByEntity[entity] = nil
				self:_RefreshActiveFlowGoalMembership(entity, nil)
			end

			local recoveredVelocityXZ, recoveredMoveTarget, recoveryStatus, recoveryReason =
				self:_BuildRecoveredFlowAdvanceInput(entity, movementState, goalPosition, position, walkSpeed)
			if recoveryStatus == "Fatal" then
				self:StopMovement(entity)
				return false, recoveryReason
			end
			if recoveryStatus == "RetryLater" then
				self._flowVelocityByEntity[entity] = Vector2.zero
				self:_StopHumanoid(entity)
				self._enemyEntityFactory:SetPathMoving(entity, false)
				return false, nil
			end
			if recoveredVelocityXZ ~= nil then
				solvedVelocityXZ = recoveredVelocityXZ
			end
			moveTarget = self:_SanitizeFlowMoveTarget(recoveredMoveTarget)
		end

		-- Mark settled entities so the goal can exclude them from active flow membership.
		if shouldSettle then
			self._flowSettledByEntity[entity] = true
			self:_RefreshActiveFlowGoalMembership(entity, movementState.GoalKey)
		end

		-- Publish the final movement command to the humanoid and path-moving state.
		self._flowVelocityByEntity[entity] = solvedVelocityXZ
		self:_IssueHumanoidMoveTo(entity, moveTarget, solvedVelocityXZ)
		self._enemyEntityFactory:SetPathMoving(entity, moveTarget ~= nil)
		return false, nil
	end
end
