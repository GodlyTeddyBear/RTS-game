--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FastFlowHelper = require(ReplicatedStorage.Utilities.FastFlowHelper)
local CombatMovementConfig = require(ReplicatedStorage.Contexts.Combat.Config.CombatMovementConfig)
local MovementTypes = require(script.Parent.Types)
local MovementMath = require(script.Parent.MovementMath)

type TFlowMovementState = MovementTypes.TFlowMovementState

local GOAL_POSITION_EPSILON = 0.01

return function(MovementService: any)
function MovementService:_StartFlow(entity: number, goalPosition: Vector3): (boolean, string?)
	local goalKey, goalWorldSample, reason = self:_AttachEntityToFlowGoal(entity, goalPosition, false)
	if goalKey == nil or goalWorldSample == nil then
		local pathfinder, mapping = self:_ResolveFastFlowRuntime()
		local entityPosition = self:_GetEntityPosition(entity)
		if pathfinder ~= nil and mapping ~= nil and entityPosition ~= nil then
			self:_EmitFastFlowEndpointDiagnostic(entity, entityPosition, goalPosition, pathfinder, mapping)
		end
		return false, reason
	end

	self._movementByEntity[entity] = {
		Mode = "Flow",
		GoalSnapshot = goalPosition,
		GoalKey = goalKey,
		GoalWorldSample = goalWorldSample,
	}
	self:_GetEntityRootPart(entity)
	self:_GetHumanoid(entity)
	self:_RefreshFlowSeparationEntitySpatialState(entity)
	self._enemyEntityFactory:SetPathMoving(entity, true)
	return true, nil
end


function MovementService:_ShouldSettleIntoClump(
	entity: number,
	goalKey: string,
	entityPosition: Vector3,
	sepConfig: any
): boolean
	if sepConfig == nil or sepConfig.ClumpIdleEnabled ~= true then
		return false
	end

	local runtime = self:_GetOrCreateFlowSeparationRuntime()
	local ownState = runtime.EntityStateById[entity]
	if ownState == nil or ownState.Radius <= 0 or ownState.GoalKey ~= goalKey or runtime.CellWidthStuds <= 0 then
		return false
	end

	local touchPadding = self:_GetFlowClumpTouchPaddingStuds(sepConfig)
	local checkedNeighbors: { [number]: boolean } = {}
	local didTouchSettledNeighbor = false

	MovementMath.ForEachCoveredSeparationCell(MovementMath.FlatXZ(entityPosition), ownState.Radius + touchPadding, runtime.CellWidthStuds, function(gx: number, gz: number)
		if didTouchSettledNeighbor then
			return
		end

		local bucket = runtime.BucketsByCell[MovementMath.PackedSeparationCellKey(gx, gz)]
		if bucket == nil then
			return
		end

		for otherEntity in bucket do
			if otherEntity ~= entity and not checkedNeighbors[otherEntity] then
				checkedNeighbors[otherEntity] = true
				local otherState = runtime.EntityStateById[otherEntity]
				if otherState ~= nil and otherState.Settled and otherState.GoalKey == goalKey and otherState.Position ~= nil then
					local touchDistance = ownState.Radius + otherState.Radius + touchPadding
					if MovementMath.XZDistance(entityPosition, otherState.Position) <= touchDistance then
						didTouchSettledNeighbor = true
						return
					end
				end
			end
		end
	end)

	return didTouchSettledNeighbor
end


function MovementService:_HandleGoalChange(
	entity: number,
	movementState: TFlowMovementState,
	goalPosition: Vector3
): (boolean, string?)
	if (goalPosition - movementState.GoalSnapshot).Magnitude <= GOAL_POSITION_EPSILON then
		return true, nil
	end

	local goalKey, goalWorldSample, reason = self:_AttachEntityToFlowGoal(entity, goalPosition, false)
	if goalKey == nil or goalWorldSample == nil then
		return false, if reason ~= nil then reason else "FastFlowGenerateFailed"
	end

	movementState.GoalSnapshot = goalPosition
	movementState.GoalKey = goalKey
	movementState.GoalWorldSample = goalWorldSample
	return true, nil
end


function MovementService:_HandleFlowArrival(
	entity: number,
	movementState: TFlowMovementState,
	entityPosition: Vector3,
	goalPosition: Vector3,
	sepConfig: any
): ("Continue" | "Settled" | "Success")
	if MovementMath.XZDistance(goalPosition, entityPosition) <= self:_GetFlowArrivalThreshold() then
		self:_StopHumanoid(entity)
		self:_ClearMovementRuntimeState(entity, movementState.GoalKey)
		return "Success"
	end

	if self._flowSettledByEntity[entity] == true then
		self:_StopHumanoid(entity)
		return "Settled"
	end

	if MovementMath.XZDistance(goalPosition, entityPosition) > self:_GetFlowClumpIdleRadiusStuds(sepConfig) then
		return "Continue"
	end

	if self:_ShouldSettleIntoClump(entity, movementState.GoalKey, entityPosition, sepConfig) then
		self:_MarkFlowSettled(entity, movementState.GoalKey)
		self:_StopHumanoid(entity)
		return "Settled"
	end

	return "Continue"
end


function MovementService:_ResolveFlowSteering(
	entity: number,
	movementState: TFlowMovementState,
	entityPosition: Vector3,
	goalPosition: Vector3,
	sepConfig: any
): (Vector3?, string?)
	local pathfinderForMerge, mapping = self:_ResolveFastFlowRuntime()
	if mapping == nil then
		return nil, "FastFlowNotConfigured"
	end

	local sharedEntry = self:_GetSharedFlowfieldEntry(movementState.GoalKey)
	if sharedEntry == nil then
		local goalKey, goalWorldSample, reason = self:_AttachEntityToFlowGoal(entity, goalPosition, true)
		if goalKey == nil or goalWorldSample == nil then
			return nil, if reason ~= nil then reason else "MissingFlowfield"
		end
		movementState.GoalKey = goalKey
		movementState.GoalWorldSample = goalWorldSample
		sharedEntry = self:_GetSharedFlowfieldEntry(goalKey)
		if sharedEntry == nil then
			return nil, "MissingFlowfield"
		end
	end

	local steering = FastFlowHelper.GetSteeringWorldXZ(sharedEntry.Flowfield, entityPosition, mapping)
	if steering == nil and pathfinderForMerge ~= nil then
		self:_IncrementFastFlowProfileCounter("MergeAttempts")
		local merged = FastFlowHelper.MergeFlowfieldWorld(pathfinderForMerge, sharedEntry.Flowfield, entityPosition, mapping)
		if merged ~= nil then
			sharedEntry.Flowfield = merged
			steering = FastFlowHelper.GetSteeringWorldXZ(sharedEntry.Flowfield, entityPosition, mapping)
		end
	end

	if steering ~= nil then
		return steering, nil
	end

	local now = os.clock()
	local repairAfter = self._flowSteeringRepairAtClockByEntity[entity] or 0
	if now < repairAfter then
		return nil, nil
	end

	self._flowSteeringRepairAtClockByEntity[entity] = now + self:_GetSharedFlowfieldRefreshCooldownSeconds(sepConfig)
	local goalKey, goalWorldSample, reason = self:_AttachEntityToFlowGoal(entity, goalPosition, true)
	if goalKey == nil or goalWorldSample == nil then
		return nil, if reason ~= nil then reason else "FastFlowGenerateFailed"
	end

	movementState.GoalKey = goalKey
	movementState.GoalWorldSample = goalWorldSample

	local refreshedEntry = self:_GetSharedFlowfieldEntry(goalKey)
	if refreshedEntry == nil then
		return nil, "MissingFlowfield"
	end

	return FastFlowHelper.GetSteeringWorldXZ(refreshedEntry.Flowfield, entityPosition, mapping), nil
end


function MovementService:_TickFlow(
	entity: number,
	movementState: TFlowMovementState
): ("Running" | "Success" | "Fail", string?)
	local pathState = self._enemyEntityFactory:GetPathState(entity)
	local goalPosition = if pathState ~= nil then pathState.GoalPosition else nil
	if goalPosition == nil then
		self:StopMovement(entity)
		return "Fail", "MissingGoalPosition"
	end

	local entityPosition = self:_GetEntityPosition(entity)
	if entityPosition == nil then
		self:StopMovement(entity)
		return "Fail", "MissingModelPosition"
	end

	-- Reattach shared flow state when the goal changes.
	local handledGoalChange, goalChangeReason = self:_HandleGoalChange(entity, movementState, goalPosition)
	if not handledGoalChange then
		self:StopMovement(entity)
		return "Fail", if goalChangeReason ~= nil then goalChangeReason else "FastFlowGenerateFailed"
	end

	local sepConfig = CombatMovementConfig.FLOW_SOFT_SEPARATION
	self:_RefreshFlowSeparationEntitySpatialState(entity, entityPosition)

	-- Stop or settle before doing any new steering work.
	local arrivalResult = self:_HandleFlowArrival(entity, movementState, entityPosition, goalPosition, sepConfig)
	if arrivalResult == "Success" then
		return "Success", nil
	end

	local humanoid = self:_GetHumanoid(entity)
	if humanoid == nil then
		self:StopMovement(entity)
		return "Fail", "MissingHumanoid"
	end

	if arrivalResult == "Settled" then
		self._enemyEntityFactory:SetPathMoving(entity, true)
		return "Running", nil
	end

	-- Resolve steering from the shared goal-cell flowfield.
	local steering, steeringReason = self:_ResolveFlowSteering(entity, movementState, entityPosition, goalPosition, sepConfig)
	if steering == nil and steeringReason ~= nil then
		self:StopMovement(entity)
		return "Fail", steeringReason
	end

	local walkSpeed = self:_ApplyCurrentMoveSpeed(entity, sepConfig)
	local useSoftSeparation = sepConfig ~= nil and sepConfig.Enabled == true

	-- Blend shared steering with local separation for still-active movers.
	if useSoftSeparation then
		local flowXZ = if steering ~= nil then Vector2.new(steering.X, steering.Z) * walkSpeed else Vector2.zero
		local sepXZ = self:_GetFlowSoftSeparationXZ(entity, sepConfig)
		local velXZ = flowXZ + sepXZ
		velXZ = MovementMath.ClampVector2Magnitude(velXZ, walkSpeed)
		local velAlpha = if type(sepConfig.VelAlpha) == "number" then math.clamp(sepConfig.VelAlpha, 0, 1) else 0.15
		local previousVel = self._flowVelByEntity[entity] or Vector2.zero
		velXZ = previousVel * (1 - velAlpha) + velXZ * velAlpha
		self._flowVelByEntity[entity] = velXZ

		local moveDirection = Vector3.new(velXZ.X, 0, velXZ.Y)
		if moveDirection.Magnitude > 0.05 then
			humanoid:Move(moveDirection.Unit)
		else
			humanoid:Move(Vector3.zero)
		end
	else
		if steering == nil then
			humanoid:Move(Vector3.zero)
		else
			humanoid:Move(steering)
		end
	end

	self._enemyEntityFactory:SetPathMoving(entity, true)
	return "Running", nil
end

end
