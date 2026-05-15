--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FastFlowHelper = require(ReplicatedStorage.Utilities.FastFlowHelper)
local Promise = require(ReplicatedStorage.Packages.Promise)
local CombatMovementConfig = require(ReplicatedStorage.Contexts.Combat.Config.CombatMovementConfig)
local MovementTypes = require(script.Parent.Types)
local MovementMath = require(script.Parent.MovementMath)

type TFlowMovementState = MovementTypes.TFlowMovementState
type TAdvanceStatus = MovementTypes.TAdvanceStatus
type TFlowVelocitySolveInput = MovementTypes.TFlowVelocitySolveInput
type TFlowVelocitySolveSnapshot = MovementTypes.TFlowVelocitySolveSnapshot
type TFlowVelocitySolveRow = MovementTypes.TFlowVelocitySolveRow
type TFlowVelocityAsyncResult = MovementTypes.TFlowVelocityAsyncResult
type TFlowVelocityAsyncState = MovementTypes.TFlowVelocityAsyncState

local GOAL_POSITION_EPSILON = 0.01
local FLOW_VELOCITY_OPERATION_NAME = "FlowVelocitySolve"
local MOVE_DIRECTION_EPSILON = 0.05

type TFlowVelocityApplyResult = {
	Status: TAdvanceStatus,
	Reason: string?,
}

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


function MovementService:_BuildPendingFlowVelocityInput(
	entity: number,
	steering: Vector3?,
	walkSpeed: number,
	sepConfig: any
): TFlowVelocitySolveInput
	local flowXZ = if steering ~= nil then Vector2.new(steering.X, steering.Z) * walkSpeed else Vector2.zero
	local velAlpha = if type(sepConfig.VelAlpha) == "number" then math.clamp(sepConfig.VelAlpha, 0, 1) else 0.15

	return {
		Entity = entity,
		FlowXZ = flowXZ,
		SeparationXZ = self:_GetFlowSoftSeparationXZ(entity, sepConfig),
		PreviousVelocityXZ = self._flowVelByEntity[entity] or Vector2.zero,
		WalkSpeed = walkSpeed,
		VelAlpha = velAlpha,
	}
end


function MovementService:_ApplyFlowMoveDirection(entity: number, velocityXZ: Vector2): (TAdvanceStatus, string?)
	local humanoid = self:_GetHumanoid(entity)
	if humanoid == nil then
		self:StopMovement(entity)
		return "Fail", "MissingHumanoid"
	end

	self._flowVelByEntity[entity] = velocityXZ

	local moveDirection = Vector3.new(velocityXZ.X, 0, velocityXZ.Y)
	if moveDirection.Magnitude > MOVE_DIRECTION_EPSILON then
		humanoid:Move(moveDirection.Unit)
	else
		humanoid:Move(Vector3.zero)
	end

	self._enemyEntityFactory:SetPathMoving(entity, true)
	return "Running", nil
end


function MovementService:_CreateFlowVelocitySolveSnapshot(
	inputs: { TFlowVelocitySolveInput }
): TFlowVelocitySolveSnapshot
	local snapshot: TFlowVelocitySolveSnapshot = {
		EntityIds = {},
		EntityIndexById = {},
		FlowX = {},
		FlowY = {},
		SeparationX = {},
		SeparationY = {},
		PreviousVelocityX = {},
		PreviousVelocityY = {},
		WalkSpeed = {},
		VelAlpha = {},
	}

	for index, input in ipairs(inputs) do
		snapshot.EntityIds[index] = input.Entity
		snapshot.EntityIndexById[input.Entity] = index
		snapshot.FlowX[index] = input.FlowXZ.X
		snapshot.FlowY[index] = input.FlowXZ.Y
		snapshot.SeparationX[index] = input.SeparationXZ.X
		snapshot.SeparationY[index] = input.SeparationXZ.Y
		snapshot.PreviousVelocityX[index] = input.PreviousVelocityXZ.X
		snapshot.PreviousVelocityY[index] = input.PreviousVelocityXZ.Y
		snapshot.WalkSpeed[index] = input.WalkSpeed
		snapshot.VelAlpha[index] = input.VelAlpha
	end

	return snapshot
end


function MovementService:_CreateFlowVelocitySolveSharedMemory(snapshot: TFlowVelocitySolveSnapshot): SharedTable
	local memory = SharedTable.new()
	local flowX = SharedTable.new()
	local flowY = SharedTable.new()
	local separationX = SharedTable.new()
	local separationY = SharedTable.new()
	local previousVelocityX = SharedTable.new()
	local previousVelocityY = SharedTable.new()
	local walkSpeed = SharedTable.new()
	local velAlpha = SharedTable.new()

	for index, value in ipairs(snapshot.FlowX) do
		flowX[index] = value
	end
	for index, value in ipairs(snapshot.FlowY) do
		flowY[index] = value
	end
	for index, value in ipairs(snapshot.SeparationX) do
		separationX[index] = value
	end
	for index, value in ipairs(snapshot.SeparationY) do
		separationY[index] = value
	end
	for index, value in ipairs(snapshot.PreviousVelocityX) do
		previousVelocityX[index] = value
	end
	for index, value in ipairs(snapshot.PreviousVelocityY) do
		previousVelocityY[index] = value
	end
	for index, value in ipairs(snapshot.WalkSpeed) do
		walkSpeed[index] = value
	end
	for index, value in ipairs(snapshot.VelAlpha) do
		velAlpha[index] = value
	end

	memory.FlowX = flowX
	memory.FlowY = flowY
	memory.SeparationX = separationX
	memory.SeparationY = separationY
	memory.PreviousVelocityX = previousVelocityX
	memory.PreviousVelocityY = previousVelocityY
	memory.WalkSpeed = walkSpeed
	memory.VelAlpha = velAlpha

	return memory
end


function MovementService:_ApplyFlowVelocityRows(
	snapshot: TFlowVelocitySolveSnapshot,
	rows: { TFlowVelocitySolveRow }
): { [number]: TFlowVelocityApplyResult }
	local resultsByEntity = {}

	for _, row in ipairs(rows) do
		local entityIndex = row.EntityIndex
		if type(entityIndex) ~= "number" then
			continue
		end

		local entity = snapshot.EntityIds[entityIndex]
		if entity == nil then
			continue
		end

		local movementState = self._movementByEntity[entity]
		if movementState == nil or movementState.Mode ~= "Flow" then
			continue
		end

		local velocityX = row.VelocityX
		local velocityY = row.VelocityY
		if type(velocityX) ~= "number" or type(velocityY) ~= "number" then
			continue
		end

		local status, reason = self:_ApplyFlowMoveDirection(entity, Vector2.new(velocityX, velocityY))
		resultsByEntity[entity] = {
			Status = status,
			Reason = reason,
		}
		self:_IncrementFastFlowProfileCounter("ParallelVelocityRowsApplied")
	end

	return resultsByEntity
end


function MovementService:_CreateFlowVelocityAsyncState(): TFlowVelocityAsyncState
	return {
		PendingRequestId = 0,
		LatestAppliedRequestId = 0,
		LatestCompletedResult = nil,
		InFlight = false,
		InFlightRequestId = nil,
		InFlightSessionUserId = nil,
		InFlightSnapshot = nil,
		LastDispatchClock = 0,
	}
end


function MovementService:_GetOrCreateFlowVelocityAsyncState(): TFlowVelocityAsyncState
	local state = self._flowVelocityAsyncState
	if state == nil then
		state = self:_CreateFlowVelocityAsyncState()
		self._flowVelocityAsyncState = state
	end
	return state
end


function MovementService:_ClearFlowVelocityAsyncState()
	self._flowVelocityAsyncState = nil
end


function MovementService:_IsFlowVelocityParallelAsyncEnabled(sepConfig: any): boolean
	return self:_IsFlowSeparationParallelEnabled(sepConfig)
		and sepConfig ~= nil
		and sepConfig.ParallelAsyncEnabled ~= false
end


function MovementService:_ShouldUsePreviousFlowVelocityParallelResult(sepConfig: any): boolean
	return sepConfig == nil or sepConfig.ParallelAsyncUsePreviousResult ~= false
end


function MovementService:_ExpireFlowVelocityAsyncRequestIfNeeded(sepConfig: any)
	local state = self._flowVelocityAsyncState
	if state == nil or not state.InFlight then
		return
	end

	local maxInFlightSeconds = self:_GetFlowSeparationParallelAsyncMaxInFlightSeconds(sepConfig)
	if os.clock() - state.LastDispatchClock <= maxInFlightSeconds then
		return
	end

	state.InFlight = false
	state.InFlightRequestId = nil
	state.InFlightSessionUserId = nil
	state.InFlightSnapshot = nil
	self:_IncrementFastFlowProfileCounter("ParallelFallbacks")
	self:_IncrementFastFlowProfileCounter("ParallelVelocityAsyncDroppedResults")
end


function MovementService:_CompleteFlowVelocityAsyncRequest(result: TFlowVelocityAsyncResult)
	local state = self._flowVelocityAsyncState
	if state == nil then
		return
	end

	if state.InFlightRequestId ~= result.RequestId then
		self:_IncrementFastFlowProfileCounter("ParallelVelocityAsyncStaleResults")
		return
	end

	if state.LatestCompletedResult ~= nil then
		self:_IncrementFastFlowProfileCounter("ParallelVelocityAsyncDroppedResults")
	end

	state.InFlight = false
	state.InFlightRequestId = nil
	state.InFlightSessionUserId = nil
	state.InFlightSnapshot = nil
	state.LatestCompletedResult = result
end


function MovementService:_ApplyCompletedFlowVelocityAsyncResult(
	sepConfig: any
): { [number]: TFlowVelocityApplyResult }?
	local state = self._flowVelocityAsyncState
	if state == nil or state.LatestCompletedResult == nil then
		return nil
	end

	local result = state.LatestCompletedResult
	state.LatestCompletedResult = nil
	self:_IncrementFastFlowProfileCounter("ParallelVelocityAsyncCompleted")

	local runtime = self:_GetOrCreateFlowSeparationRuntime()
	local isStaleResult = result.RequestId <= state.LatestAppliedRequestId
		or result.SessionUserId ~= runtime.SessionUserId
	if isStaleResult then
		self:_IncrementFastFlowProfileCounter("ParallelVelocityAsyncStaleResults")
		return nil
	end

	state.LatestAppliedRequestId = result.RequestId
	if result.Err ~= nil or result.Rows == nil then
		self:_IncrementFastFlowProfileCounter("ParallelFallbacks")
		self:_IncrementFastFlowProfileCounter("ParallelVelocityAsyncErrorFallbacks")
		return nil
	end

	local resultsByEntity = self:_ApplyFlowVelocityRows(result.Snapshot, result.Rows)
	self:_IncrementFastFlowProfileCounter("ParallelVelocityAsyncApplied")
	return resultsByEntity
end


function MovementService:_DispatchFlowVelocityWithParallelQueryAsync(
	snapshot: TFlowVelocitySolveSnapshot,
	sepConfig: any
): "Dispatched" | "InFlight" | "BelowThreshold" | "Failed"
	local entityCount = #snapshot.EntityIds
	if entityCount < self:_GetFlowVelocityParallelMinEntityCount(sepConfig) then
		return "BelowThreshold"
	end

	local state = self:_GetOrCreateFlowVelocityAsyncState()
	self:_ExpireFlowVelocityAsyncRequestIfNeeded(sepConfig)
	if state.InFlight then
		self:_IncrementFastFlowProfileCounter("ParallelVelocityAsyncInFlightSkips")
		return "InFlight"
	end

	local runtime = self:_GetOrCreateFlowSeparationRuntime()
	local requestId = state.PendingRequestId + 1
	local sessionUserId = runtime.SessionUserId
	state.PendingRequestId = requestId
	state.InFlight = true
	state.InFlightRequestId = requestId
	state.InFlightSessionUserId = sessionUserId
	state.InFlightSnapshot = snapshot
	state.LastDispatchClock = os.clock()

	local promise: typeof(Promise.new(function() end))? = nil
	local ok = pcall(function()
		local runner = self:_GetOrCreateFlowSeparationParallelRunner(sepConfig)
		local batchSize = self:_GetFlowVelocityParallelBatchSize(sepConfig)
		runner:SetLocalMemory(FLOW_VELOCITY_OPERATION_NAME, self:_CreateFlowVelocitySolveSharedMemory(snapshot))
		promise = runner:RunAsync(FLOW_VELOCITY_OPERATION_NAME, {
			WorkCount = entityCount,
			BatchSize = batchSize,
			TimeoutSeconds = self:_GetFlowVelocityParallelTimeoutSeconds(sepConfig),
		})
	end)

	if not ok or promise == nil then
		state.InFlight = false
		state.InFlightRequestId = nil
		state.InFlightSessionUserId = nil
		state.InFlightSnapshot = nil
		self:_IncrementFastFlowProfileCounter("ParallelFallbacks")
		self:_IncrementFastFlowProfileCounter("ParallelVelocityAsyncErrorFallbacks")
		return "Failed"
	end

	promise:andThen(function(resultRows)
		self:_CompleteFlowVelocityAsyncRequest({
			RequestId = requestId,
			SessionUserId = sessionUserId,
			Snapshot = snapshot,
			Rows = resultRows :: any,
			Err = nil,
		})
	end):catch(function(resultErr)
		self:_CompleteFlowVelocityAsyncRequest({
			RequestId = requestId,
			SessionUserId = sessionUserId,
			Snapshot = snapshot,
			Rows = nil,
			Err = resultErr,
		})
	end)

	self:_IncrementFastFlowProfileCounter("ParallelVelocityDispatches")
	self:_IncrementFastFlowProfileCounter("ParallelVelocityEntitiesDispatched", entityCount)
	self:_IncrementFastFlowProfileCounter("ParallelVelocityAsyncDispatches")
	return "Dispatched"
end


function MovementService:_ResolvePendingFlowVelocityMoves(
	inputs: { TFlowVelocitySolveInput }
): ()
	if #inputs == 0 then
		return
	end

	local sepConfig = CombatMovementConfig.FLOW_SOFT_SEPARATION
	if not self:_IsFlowSeparationParallelEnabled(sepConfig) or not self:_IsFlowVelocityParallelAsyncEnabled(sepConfig) then
		return
	end

	local snapshot = self:_CreateFlowVelocitySolveSnapshot(inputs)
	self:_DispatchFlowVelocityWithParallelQueryAsync(snapshot, sepConfig)
end


function MovementService:_TickFlow(
	entity: number,
	movementState: TFlowMovementState
): ("Running" | "Success" | "Fail", string?, TFlowVelocitySolveInput?)
	local pathState = self._enemyEntityFactory:GetPathState(entity)
	local goalPosition = if pathState ~= nil then pathState.GoalPosition else nil
	if goalPosition == nil then
		self:StopMovement(entity)
		return "Fail", "MissingGoalPosition", nil
	end

	local entityPosition = self:_GetEntityPosition(entity)
	if entityPosition == nil then
		self:StopMovement(entity)
		return "Fail", "MissingModelPosition", nil
	end

	-- Reattach shared flow state when the goal changes.
	local handledGoalChange, goalChangeReason = self:_HandleGoalChange(entity, movementState, goalPosition)
	if not handledGoalChange then
		self:StopMovement(entity)
		return "Fail", if goalChangeReason ~= nil then goalChangeReason else "FastFlowGenerateFailed", nil
	end

	local sepConfig = CombatMovementConfig.FLOW_SOFT_SEPARATION
	self:_RefreshFlowSeparationEntitySpatialState(entity, entityPosition)

	-- Stop or settle before doing any new steering work.
	local arrivalResult = self:_HandleFlowArrival(entity, movementState, entityPosition, goalPosition, sepConfig)
	if arrivalResult == "Success" then
		return "Success", nil, nil
	end

	local humanoid = self:_GetHumanoid(entity)
	if humanoid == nil then
		self:StopMovement(entity)
		return "Fail", "MissingHumanoid", nil
	end

	if arrivalResult == "Settled" then
		self._enemyEntityFactory:SetPathMoving(entity, true)
		return "Running", nil, nil
	end

	-- Resolve steering from the shared goal-cell flowfield.
	local steering, steeringReason = self:_ResolveFlowSteering(entity, movementState, entityPosition, goalPosition, sepConfig)
	if steering == nil and steeringReason ~= nil then
		self:StopMovement(entity)
		return "Fail", steeringReason, nil
	end

	local walkSpeed = self:_ApplyCurrentMoveSpeed(entity, sepConfig)
	local useSoftSeparation = sepConfig ~= nil and sepConfig.Enabled == true

	-- Queue the final velocity solve so the batch can run through ParallelQuery.
	if useSoftSeparation then
		return "Running", nil, self:_BuildPendingFlowVelocityInput(entity, steering, walkSpeed, sepConfig)
	end

	-- Keep the non-soft-separation path fully serial.
	if steering == nil then
		humanoid:Move(Vector3.zero)
	else
		humanoid:Move(steering)
	end

	self._enemyEntityFactory:SetPathMoving(entity, true)
	return "Running", nil, nil
end

end
