--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FastFlowHelper = require(ReplicatedStorage.Utilities.FastFlowHelper)
local CombatMovementConfig = require(ReplicatedStorage.Contexts.Combat.Config.CombatMovementConfig)
local ParallelQuery = require(ReplicatedStorage.Utilities.ParallelQuery)
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
local ManagedJobPolicies = ParallelQuery.ManagedJobPolicies
local ResultApplication = ParallelQuery.ResultApplication
local SharedMemoryAuthoring = ParallelQuery.SharedMemoryAuthoring
local ValidationHelpers = ParallelQuery.ValidationHelpers

type TFlowVelocityApplyResult = {
	Status: TAdvanceStatus,
	Reason: string?,
}

type TManagedJob = ParallelQuery.TManagedJob

return function(MovementService: any)
function MovementService:_StartFlow(entity: number, goalPosition: Vector3): (boolean, string?)
	local goalKey, goalWorldSample, reason = self:_AttachEntityToFlowGoal(entity, goalPosition, false)
	if goalKey == nil or goalWorldSample == nil then
		local pathfinder, mapping = self:_ResolveFastFlowRuntime()
		local entityPosition = self:_GetEntityPosition(entity)
		if pathfinder and mapping and entityPosition then
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
		return false, reason or "FastFlowGenerateFailed"
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
			return nil, reason or "MissingFlowfield"
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
		return nil, reason or "FastFlowGenerateFailed"
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
	local flowXZ = if steering then Vector2.new(steering.X, steering.Z) * walkSpeed else Vector2.zero
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
	local builder = SharedMemoryAuthoring.CreateSnapshotBuilder()
	SharedMemoryAuthoring.SetArrayValues(builder, "FlowX", snapshot.FlowX)
	SharedMemoryAuthoring.SetArrayValues(builder, "FlowY", snapshot.FlowY)
	SharedMemoryAuthoring.SetArrayValues(builder, "SeparationX", snapshot.SeparationX)
	SharedMemoryAuthoring.SetArrayValues(builder, "SeparationY", snapshot.SeparationY)
	SharedMemoryAuthoring.SetArrayValues(builder, "PreviousVelocityX", snapshot.PreviousVelocityX)
	SharedMemoryAuthoring.SetArrayValues(builder, "PreviousVelocityY", snapshot.PreviousVelocityY)
	SharedMemoryAuthoring.SetArrayValues(builder, "WalkSpeed", snapshot.WalkSpeed)
	SharedMemoryAuthoring.SetArrayValues(builder, "VelAlpha", snapshot.VelAlpha)
	return SharedMemoryAuthoring.BuildSharedMemory(builder)
end


function MovementService:_ApplyFlowVelocityRows(
	snapshot: TFlowVelocitySolveSnapshot,
	rows: { TFlowVelocitySolveRow }
): { [number]: TFlowVelocityApplyResult }
	local resultsByEntity = {}

	ResultApplication.ApplyRows({
		Rows = rows,
		ValidateRow = function(row)
			local indexValidation = ValidationHelpers.RequireIndexFields(row, { "EntityIndex" }, #snapshot.EntityIds)
			if not indexValidation.IsValid then
				return indexValidation
			end

			return ValidationHelpers.RequireNumberFields(row, { "VelocityX", "VelocityY" })
		end,
		ResolveTarget = function(row)
			local entity = ResultApplication.ResolveIndexedValue(row, "EntityIndex", snapshot.EntityIds)
			if entity == nil then
				return
			end

			local movementState = self._movementByEntity[entity]
			if movementState == nil or movementState.Mode ~= "Flow" then
				return
			end

			return entity
		end,
		ApplyRow = function(entity, row)
			local status, reason = self:_ApplyFlowMoveDirection(entity, Vector2.new(row.VelocityX, row.VelocityY))
			resultsByEntity[entity] = {
				Status = status,
				Reason = reason,
			}
			self:_IncrementFastFlowProfileCounter("ParallelVelocityRowsApplied")
		end,
	})

	return resultsByEntity
end


function MovementService:_IsFlowVelocityParallelAsyncEnabled(sepConfig: any): boolean
	return self:_IsFlowSeparationParallelEnabled(sepConfig)
		and sepConfig ~= nil
		and sepConfig.ParallelAsyncEnabled ~= false
end


function MovementService:_ShouldUsePreviousFlowVelocityParallelResult(sepConfig: any): boolean
	return sepConfig == nil or sepConfig.ParallelAsyncUsePreviousResult ~= false
end


function MovementService:_CreateFlowVelocityManagedJob(sepConfig: any): TManagedJob
	local runner = self:_GetOrCreateFlowSeparationParallelRunner(sepConfig)
	return runner:CreateManagedJob({
		OperationName = FLOW_VELOCITY_OPERATION_NAME,
		BuildLocalMemory = function(snapshot: TFlowVelocitySolveSnapshot)
			return self:_CreateFlowVelocitySolveSharedMemory(snapshot)
		end,
		BuildRunRequest = function(snapshot: TFlowVelocitySolveSnapshot)
			return {
				WorkCount = #snapshot.EntityIds,
				BatchSize = self:_GetFlowVelocityParallelBatchSize(sepConfig),
				TimeoutSeconds = self:_GetFlowVelocityParallelTimeoutSeconds(sepConfig),
			}
		end,
		GetSessionToken = function(_snapshot: TFlowVelocitySolveSnapshot)
			local runtime = self:_GetOrCreateFlowSeparationRuntime()
			return runtime.SessionUserId
		end,
		MaxInFlightSeconds = self:_GetFlowSeparationParallelAsyncMaxInFlightSeconds(sepConfig),
		Policy = ManagedJobPolicies.StrictFreshOnly,
	})
end


function MovementService:_GetOrCreateFlowVelocityManagedJob(sepConfig: any): TManagedJob
	local job = self._flowVelocityManagedJob
	if job == nil then
		job = self:_CreateFlowVelocityManagedJob(sepConfig)
		self._flowVelocityManagedJob = job
	end
	return job
end


function MovementService:_ObserveFlowVelocityManagedJob(job: TManagedJob)
	local status = job:GetStatus()
	if status.LastError ~= self._flowVelocityManagedJobLastObservedError then
		self._flowVelocityManagedJobLastObservedError = status.LastError
		if type(status.LastError) == "table" and status.LastError.Kind == "Timeout" then
			self:_IncrementFastFlowProfileCounter("ParallelFallbacks")
			self:_IncrementFastFlowProfileCounter("ParallelVelocityAsyncDroppedResults")
		end
	end

	return status
end


function MovementService:_ApplyCompletedFlowVelocityAsyncResult(
	sepConfig: any
): { [number]: TFlowVelocityApplyResult }?
	local job = self._flowVelocityManagedJob
	if job == nil then
		return
	end

	local status = self:_ObserveFlowVelocityManagedJob(job)
	if not status.HasCompletedResult then
		return
	end

	local runtime = self:_GetOrCreateFlowSeparationRuntime()
	self:_IncrementFastFlowProfileCounter("ParallelVelocityAsyncCompleted")
	local managedResult = job:PollCompleted(runtime.SessionUserId)
	if managedResult == nil then
		self:_IncrementFastFlowProfileCounter("ParallelVelocityAsyncStaleResults")
		return
	end

	local snapshot = managedResult.Payload :: TFlowVelocitySolveSnapshot
	if managedResult.Err ~= nil or managedResult.Rows == nil then
		self:_IncrementFastFlowProfileCounter("ParallelFallbacks")
		self:_IncrementFastFlowProfileCounter("ParallelVelocityAsyncErrorFallbacks")
		return
	end

	local resultsByEntity = self:_ApplyFlowVelocityRows(snapshot, managedResult.Rows :: any)
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

	local job = self:_GetOrCreateFlowVelocityManagedJob(sepConfig)
	local status = self:_ObserveFlowVelocityManagedJob(job)
	if status.InFlight then
		self:_IncrementFastFlowProfileCounter("ParallelVelocityAsyncInFlightSkips")
		return "InFlight"
	end

	local ok, dispatchStatus = pcall(function()
		return job:Dispatch(snapshot)
	end)
	if not ok then
		self:_IncrementFastFlowProfileCounter("ParallelFallbacks")
		self:_IncrementFastFlowProfileCounter("ParallelVelocityAsyncErrorFallbacks")
		return "Failed"
	end

	if dispatchStatus == "InFlight" then
		self:_IncrementFastFlowProfileCounter("ParallelVelocityAsyncInFlightSkips")
		return "InFlight"
	end

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
	local goalPosition = pathState and pathState.GoalPosition
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
		return "Fail", goalChangeReason or "FastFlowGenerateFailed", nil
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
