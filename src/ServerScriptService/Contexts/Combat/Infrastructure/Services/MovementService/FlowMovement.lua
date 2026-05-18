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

	function MovementService:_GetFlowAgentRadiusStuds(entity: number): number
		local agentParams = self:_GetAgentParams(entity)
		local radius = agentParams.AgentRadius
		if type(radius) == "number" and radius > 0 then
			return radius
		end
		return 2
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

	function MovementService:_StepFlowAdvance(
		entity: number,
		movementState: TFlowMovementState,
		services: any?
	): (boolean, string?)
		self:_AdvanceFlowPipeline(services)

		local invalidReason = self._flowInvalidReasonByEntity[entity]
		if invalidReason ~= nil then
			self:StopMovement(entity)
			return false, invalidReason
		end

		local latestParallelSolve = self._flowLatestParallelSolve :: TFlowPublishedSolve?
		if latestParallelSolve == nil then
			return false, nil
		end

		local frameState = self._flowPublishedFrameState :: TFlowPublishedFrameState?
		if frameState == nil then
			return false, nil
		end

		local goalKey = frameState.GoalKeyByEntity[entity]
		local publishedGoalKey = latestParallelSolve.GoalKeyByEntity[entity]
		if goalKey == nil or publishedGoalKey == nil or publishedGoalKey ~= goalKey then
			return false, nil
		end

		local goalPosition = frameState.GoalPositionByEntity[entity]
		local goalWorldSample = frameState.GoalWorldSampleByEntity[entity]
		local position = frameState.PositionByEntity[entity]
		local walkSpeed = frameState.WalkSpeedByEntity[entity]
		if goalPosition == nil or goalWorldSample == nil or position == nil or walkSpeed == nil then
			return false, nil
		end

		local velocityXZ = latestParallelSolve.VelocityByEntity[entity]
		if velocityXZ == nil then
			return false, nil
		end

		local solvedVelocityXZ, moveTarget, didArrive, shouldSettle, _hasSteering = self:_BuildFlowSolutionForInput(
			goalPosition,
			goalWorldSample,
			position,
			walkSpeed,
			frameState.IsSettledByEntity[entity] == true,
			velocityXZ,
			latestParallelSolve.TouchedSettledNeighborByEntity[entity] == true
		)

		if didArrive then
			self._flowVelocityByEntity[entity] = Vector2.zero
			self._flowSettledByEntity[entity] = nil
			self:_StopHumanoid(entity)
			self._enemyEntityFactory:SetPathMoving(entity, false)
			return true, nil
		end

		if shouldSettle then
			self._flowSettledByEntity[entity] = true
			self:_RefreshActiveFlowGoalMembership(entity, movementState.GoalKey)
		end

		self._flowVelocityByEntity[entity] = solvedVelocityXZ
		self:_IssueHumanoidMoveTo(entity, moveTarget, solvedVelocityXZ)
		self._enemyEntityFactory:SetPathMoving(entity, moveTarget ~= nil)
		return false, nil
	end
end
