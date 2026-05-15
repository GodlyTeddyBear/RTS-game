--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FastFlowHelper = require(ReplicatedStorage.Utilities.FastFlowHelper)
local CombatMovementConfig = require(ReplicatedStorage.Contexts.Combat.Config.CombatMovementConfig)
local MovementTypes = require(script.Parent.Types)
local MovementMath = require(script.Parent.MovementMath)

type TFlowMovementState = MovementTypes.TFlowMovementState
type TAdvanceStatus = MovementTypes.TAdvanceStatus
type TFlowVelocitySolveInput = MovementTypes.TFlowVelocitySolveInput
type TFlowVelocitySolveSnapshot = MovementTypes.TFlowVelocitySolveSnapshot
type TFlowVelocitySolveRow = MovementTypes.TFlowVelocitySolveRow

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


function MovementService:_SolveFlowVelocityLocally(input: TFlowVelocitySolveInput): Vector2
	local targetVelocityXZ = MovementMath.ClampVector2Magnitude(input.FlowXZ + input.SeparationXZ, input.WalkSpeed)
	return input.PreviousVelocityXZ * (1 - input.VelAlpha) + targetVelocityXZ * input.VelAlpha
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


function MovementService:_ResolveFlowVelocityWithParallelQuery(
	snapshot: TFlowVelocitySolveSnapshot,
	sepConfig: any
): { TFlowVelocitySolveRow }?
	local entityCount = #snapshot.EntityIds
	if entityCount < self:_GetFlowVelocityParallelMinEntityCount(sepConfig) then
		return nil
	end

	local rows: { TFlowVelocitySolveRow }? = nil
	local err: any = nil
	local completed = false
	local ok = pcall(function()
		local runner = self:_GetOrCreateFlowSeparationParallelRunner(sepConfig)
		runner:SetLocalMemory(FLOW_VELOCITY_OPERATION_NAME, self:_CreateFlowVelocitySolveSharedMemory(snapshot))
		runner:Run(FLOW_VELOCITY_OPERATION_NAME, {
			WorkCount = entityCount,
			BatchSize = self:_GetFlowVelocityParallelBatchSize(sepConfig),
			TimeoutSeconds = self:_GetFlowVelocityParallelTimeoutSeconds(sepConfig),
		}, function(resultRows, resultErr)
			rows = resultRows :: any
			err = resultErr
			completed = true
		end)
	end)

	if not ok then
		self:_IncrementFastFlowProfileCounter("ParallelFallbacks")
		return nil
	end

	while not completed do
		task.wait()
	end

	if err ~= nil or rows == nil then
		self:_IncrementFastFlowProfileCounter("ParallelFallbacks")
		return nil
	end

	self:_IncrementFastFlowProfileCounter("ParallelVelocityDispatches")
	self:_IncrementFastFlowProfileCounter("ParallelVelocityEntitiesDispatched", entityCount)
	return rows
end


function MovementService:_ResolvePendingFlowVelocityMoves(
	inputs: { TFlowVelocitySolveInput }
): { [number]: TFlowVelocityApplyResult }
	local sepConfig = CombatMovementConfig.FLOW_SOFT_SEPARATION
	local snapshot = self:_CreateFlowVelocitySolveSnapshot(inputs)

	-- Solve final blended velocities in workers when the batch is large enough.
	if self:_IsFlowSeparationParallelEnabled(sepConfig) then
		local rows = self:_ResolveFlowVelocityWithParallelQuery(snapshot, sepConfig)
		if rows ~= nil then
			return self:_ApplyFlowVelocityRows(snapshot, rows)
		end
	end

	-- Keep a synchronous fallback so movement remains stable on small batches and worker failures.
	local resultsByEntity = {}
	for _, input in ipairs(inputs) do
		local status, reason = self:_ApplyFlowMoveDirection(input.Entity, self:_SolveFlowVelocityLocally(input))
		resultsByEntity[input.Entity] = {
			Status = status,
			Reason = reason,
		}
	end

	return resultsByEntity
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
