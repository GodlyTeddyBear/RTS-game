--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DebugConfig = require(ReplicatedStorage.Config.DebugConfig)
local DebugPlus = require(ReplicatedStorage.Utilities.DebugPlus)
local StateMachine = require(ReplicatedStorage.Utilities.StateMachine)
local TableRecycler = require(ReplicatedStorage.Utilities.TableRecycler)
local MovementTypes = require(script.Types)

--[=[
    @class MovementService
    Owns combat movement orchestration for path and shared-flow movement modes.

    The service wires runtime dependencies, starts and stops entity movement,
    and manages the flow pipeline that publishes separation solves to the frame step.
    @server
]=]
local MovementService = {}
MovementService.__index = MovementService

-- â”€â”€ Types â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
type EnemyMovementMode = MovementTypes.EnemyMovementMode
type TFlowPipelineStateMachineConfig = StateMachine.TStateMachineConfig<TFlowPipelineState>
type TCombatLoopServiceLike = MovementTypes.TCombatLoopServiceLike
type TMovementActorBinding = MovementTypes.TMovementActorBinding
type TMovementActorKey = MovementTypes.TMovementActorKey
type TFastFlowGridMapping = MovementTypes.TFastFlowGridMapping
type TFastFlowPathfinder = MovementTypes.TFastFlowPathfinder
type TFlowMovementState = MovementTypes.TFlowMovementState
type TFlowPipelineStateMachineLike = MovementTypes.TFlowPipelineStateMachineLike
type TMovementTempEntityArray = MovementTypes.TMovementTempEntityArray
type TMovementTempMap = MovementTypes.TMovementTempMap
type TFlowSchedulerServices = MovementTypes.TFlowSchedulerServices
type TFlowfieldDebugRenderer = MovementTypes.TFlowfieldDebugRenderer
type TLockOnServiceLike = MovementTypes.TLockOnServiceLike
type TMovementState = MovementTypes.TMovementState
type TSharedFlowfieldEntry = MovementTypes.TSharedFlowfieldEntry
type TSharedCompiledHandle = MovementTypes.TSharedCompiledHandle
type TTableRecyclerLike = MovementTypes.TTableRecyclerLike
type TFlowActorRefs = MovementTypes.TFlowActorRefs
type TFlowPipelineState = MovementTypes.TFlowPipelineState
type TFlowSeparationDispatchPayload = MovementTypes.TFlowSeparationDispatchPayload
type TFlowPublishedFrameState = MovementTypes.TFlowPublishedFrameState
type TFlowSeparationWorkerPayload = MovementTypes.TFlowSeparationWorkerPayload

local MOVEMENT_PROFILING_ENABLED = DebugConfig.COMBAT_MOVEMENT_PROFILING
local STEP_ADVANCE_PROFILE_TAG = "Combat:MovementService:StepAdvance"
local FLOW_STEP_ADVANCE_PROFILE_TAG = "Combat:MovementService:Flow:StepAdvance"

local FLOW_PIPELINE_TRANSITIONS: { [TFlowPipelineState]: { [TFlowPipelineState]: boolean } } = {
	Idle = {
		BuildingSnapshot = true,
	},
	BuildingSnapshot = {
		Idle = true,
		PreparingSharedPacket = true,
	},
	PreparingSharedPacket = {
		Idle = true,
		PreparingRunRequest = true,
	},
	PreparingRunRequest = {
		Idle = true,
		Dispatching = true,
	},
	Dispatching = {
		Idle = true,
		Waiting = true,
	},
	Waiting = {
		Idle = true,
		Publishing = true,
	},
	Publishing = {
		Idle = true,
	},
}

-- Build the flow pipeline state machine so runtime transitions stay validated in one place.
local function _CreateFlowPipelineStateMachine(): TFlowPipelineStateMachineLike
	local config: TFlowPipelineStateMachineConfig = {
		InitialState = "Idle",
		Transitions = FLOW_PIPELINE_TRANSITIONS,
		ErrorType = "IllegalFlowPipelineTransition",
		ErrorMessage = "Flow pipeline transition is not allowed",
		ErrorDataBuilder = function(fromState: TFlowPipelineState, toState: TFlowPipelineState)
			return {
				From = fromState,
				To = toState,
			}
		end,
	}

	return StateMachine.new(config) :: TFlowPipelineStateMachineLike
end

require(script.ActorRefs)(MovementService)
require(script.PathMovement)(MovementService)
require(script.SharedFlowfields)(MovementService)
require(script.FlowFrameState)
require(script.FlowSnapshot)(MovementService)
require(script.FlowPipeline)(MovementService)
require(script.FlowMovement)(MovementService)

--[=[
    Creates a new movement service with empty runtime caches and state tables.
    @within MovementService
    @return MovementService -- Service instance ready for dependency wiring.
]=]
function MovementService.new()
	local self = setmetatable({}, MovementService)
	self._movementBindingByActorKey = {} :: { [TMovementActorKey]: TMovementActorBinding }
	self._movementByActorKey = {} :: { [TMovementActorKey]: TMovementState }
	self._movementTempTableRecycler = nil
	self._fastFlowPathfinder = nil
	self._fastFlowMapping = nil
	self._sharedFlowfieldsByGoalKey = {} :: { [string]: TSharedFlowfieldEntry }
	self._flowGoalKeyByActorKey = {} :: { [TMovementActorKey]: string }
	self._activeFlowActorKeysByGoalKey = {} :: { [string]: { [TMovementActorKey]: boolean } }
	self._flowSettledByActorKey = {} :: { [TMovementActorKey]: boolean }
	self._flowActorRefsByActorKey = {} :: { [TMovementActorKey]: TFlowActorRefs }
	self._flowVelocityByActorKey = {} :: { [TMovementActorKey]: Vector2 }
	self._flowFrameSerial = 0
	self._flowPipelineStateMachine = _CreateFlowPipelineStateMachine()
	self._flowPipelineTickId = nil :: number?
	self._flowInvalidReasonByActorKey = {}
	self._flowRecoveredOpenCellByActorKey = {} :: { [TMovementActorKey]: Vector2 }
	self._flowCurrentSessionUserId = nil :: number?
	self._flowSeparationParallelRunner = nil
	self._flowSeparationManagedJob = nil
	self._flowFrameStateRecycler = nil
	self._flowFrameState = nil
	self._flowLatestParallelSolve = nil
	self._flowReusableGoalKeyByActorKey = {} :: { [TMovementActorKey]: string }
	self._flowReusableGoalPositionByActorKey = {} :: { [TMovementActorKey]: Vector3 }
	self._flowReusableGoalWorldSampleByActorKey = {} :: { [TMovementActorKey]: Vector3 }
	self._flowReusablePositionByActorKey = {} :: { [TMovementActorKey]: Vector3 }
	self._flowReusableWalkSpeedByActorKey = {} :: { [TMovementActorKey]: number }
	self._flowReusableIsSettledByActorKey = {} :: { [TMovementActorKey]: boolean }
	self._flowPublishedVelocityByActorKey = {} :: { [TMovementActorKey]: Vector2 }
	self._flowPublishedTouchedSettledNeighborByActorKey = {} :: { [TMovementActorKey]: boolean }
	self._flowPublishedGoalKeyByActorKey = {} :: { [TMovementActorKey]: string }
	self._flowPublishedGoalPositionByActorKey = {} :: { [TMovementActorKey]: Vector3 }
	self._flowPublishedGoalWorldSampleByActorKey = {} :: { [TMovementActorKey]: Vector3 }
	self._flowPublishedPositionByActorKey = {} :: { [TMovementActorKey]: Vector3 }
	self._flowPublishedWalkSpeedByActorKey = {} :: { [TMovementActorKey]: number }
	self._flowPublishedIsSettledByActorKey = {} :: { [TMovementActorKey]: boolean }
	self._flowRepresentativeStarts = {} :: { Vector3 }
	self._flowPublishedSolve = {
		TickId = 0,
		VelocityByEntity = self._flowPublishedVelocityByActorKey,
		TouchedSettledNeighborByEntity = self._flowPublishedTouchedSettledNeighborByActorKey,
		GoalKeyByEntity = self._flowPublishedGoalKeyByActorKey,
	}
	self._flowReusableFrameState = {
		GoalKeyByEntity = self._flowReusableGoalKeyByActorKey,
		GoalPositionByEntity = self._flowReusableGoalPositionByActorKey,
		GoalWorldSampleByEntity = self._flowReusableGoalWorldSampleByActorKey,
		PositionByEntity = self._flowReusablePositionByActorKey,
		WalkSpeedByEntity = self._flowReusableWalkSpeedByActorKey,
		IsSettledByEntity = self._flowReusableIsSettledByActorKey,
	} :: TFlowPublishedFrameState
	self._flowPublishedFrameState = {
		GoalKeyByEntity = self._flowPublishedGoalKeyByActorKey,
		GoalPositionByEntity = self._flowPublishedGoalPositionByActorKey,
		GoalWorldSampleByEntity = self._flowPublishedGoalWorldSampleByActorKey,
		PositionByEntity = self._flowPublishedPositionByActorKey,
		WalkSpeedByEntity = self._flowPublishedWalkSpeedByActorKey,
		IsSettledByEntity = self._flowPublishedIsSettledByActorKey,
	} :: TFlowPublishedFrameState
	self._flowDispatchedSeparationSnapshot = nil
	self._flowDispatchedActorKeys = nil :: { TMovementActorKey }?
	self._flowDispatchedGoalKeyByActorKey = nil
	self._flowDispatchedFrameState = nil :: TFlowPublishedFrameState?
	self._flowStaticSharedMemory = nil :: SharedTable?
	self._flowStaticSharedMemoryHandle = nil :: TSharedCompiledHandle?
	self._flowStaticSharedMemoryPathfinder = nil
	self._flowPreparedWorkerPayload = nil :: TFlowSeparationWorkerPayload?
	self._flowDispatchPayload = nil :: TFlowSeparationDispatchPayload?
	self._flowWallKeyCachePathfinder = nil
	self._flowWallGridCache = nil
	self._flowWallGridHalfSize = nil
	self._flowWallGridWidth = nil
	return self
end

--[=[
    Resolves context dependencies for the movement service.
    @within MovementService
    @param registry any -- Registry instance supplied by the context bootstrap.
    @param _name string -- Registry key used to register the service.
]=]
function MovementService:Init(registry: MovementTypes.TRegistryLike, _name: string)
	self._registry = registry
	self._combatLoopService = registry:Get("CombatLoopService") :: TCombatLoopServiceLike?
end

--[=[
    Starts the movement service after dependency registration completes.
    @within MovementService
]=]
function MovementService:Start()
	self:_PrimeFlowSeparationParallelRuntime()
end

function MovementService:_RegisterMovementBinding(binding: TMovementActorBinding): TMovementActorKey
	local actorKey = binding.ActorKey
	self._movementBindingByActorKey[actorKey] = binding
	return actorKey
end

function MovementService:_GetMovementBinding(actorKey: TMovementActorKey): TMovementActorBinding?
	return self._movementBindingByActorKey[actorKey]
end

function MovementService:_GetMovementEntityId(actorKey: TMovementActorKey): number?
	local binding = self:_GetMovementBinding(actorKey)
	return if binding ~= nil then binding.EntityId else nil
end

--[=[
    Wires the lock-on service used to keep boids and humanoids facing correctly.
    @within MovementService
    @param lockOnService any -- Lock-on service used during movement updates.
]=]
function MovementService:ConfigureLockOnService(lockOnService: TLockOnServiceLike)
	self._lockOnService = lockOnService
end

--[=[
    Stores the fast-flow runtime used by shared flowfield movement.
    @within MovementService
    @param pathfinder any? -- Fast-flow pathfinder instance or `nil` to clear it.
    @param mapping FastFlowHelper.TFlowGridMapping? -- Flow-grid mapping or `nil` to clear it.
]=]
function MovementService:ConfigureFastFlow(pathfinder: TFastFlowPathfinder?, mapping: TFastFlowGridMapping?)
	self._fastFlowPathfinder = pathfinder
	self._fastFlowMapping = mapping
	self._flowWallKeyCachePathfinder = nil
	self._flowWallGridCache = nil
	self._flowWallGridHalfSize = nil
	self._flowWallGridWidth = nil
end

--[=[
    Registers the optional flowfield debug renderer used by combat diagnostics.
    @within MovementService
    @param renderer ((any, FastFlowHelper.TFlowGridMapping, Vector3) -> ())? -- Debug renderer callback or `nil`.
]=]
function MovementService:ConfigureFlowfieldDebugRenderer(renderer: TFlowfieldDebugRenderer?)
	self._flowfieldDebugRenderer = renderer
end

--[=[
    Finalizes the current advance frame after all entity movement has stepped.
    @within MovementService
]=]
function MovementService:FinalizeAdvanceFrame() end

--[=[
    Clears the fast-flow runtime caches and rebuilds the pipeline state machine.
    @within MovementService
]=]
function MovementService:ResetFastFlowRuntime()
	-- Clear all shared-flow state so the next session starts from a clean runtime.
	self:_ResetFlowInfrastructureRuntime()

	-- Drop every cached flow goal and published frame buffer.
	table.clear(self._sharedFlowfieldsByGoalKey)
	table.clear(self._flowGoalKeyByActorKey)
	table.clear(self._activeFlowActorKeysByGoalKey)
	table.clear(self._flowSettledByActorKey)
	table.clear(self._flowVelocityByActorKey)
	table.clear(self._flowReusableGoalKeyByActorKey)
	table.clear(self._flowReusableGoalPositionByActorKey)
	table.clear(self._flowReusableGoalWorldSampleByActorKey)
	table.clear(self._flowReusablePositionByActorKey)
	table.clear(self._flowReusableWalkSpeedByActorKey)
	table.clear(self._flowReusableIsSettledByActorKey)
	table.clear(self._flowPublishedVelocityByActorKey)
	table.clear(self._flowPublishedTouchedSettledNeighborByActorKey)
	table.clear(self._flowPublishedGoalKeyByActorKey)
	table.clear(self._flowPublishedGoalPositionByActorKey)
	table.clear(self._flowPublishedGoalWorldSampleByActorKey)
	table.clear(self._flowPublishedPositionByActorKey)
	table.clear(self._flowPublishedWalkSpeedByActorKey)
	table.clear(self._flowPublishedIsSettledByActorKey)

	-- Reset the pipeline bookkeeping and invalidate any stuck recovery state.
	table.clear(self._flowRepresentativeStarts)
	self._flowPipelineTickId = nil
	table.clear(self._flowInvalidReasonByActorKey)
	table.clear(self._flowRecoveredOpenCellByActorKey)
	self._flowLatestParallelSolve = nil
	self._flowDispatchedActorKeys = nil
	self._flowDispatchedGoalKeyByActorKey = nil
	self._flowDispatchedFrameState = nil
	self._flowPreparedWorkerPayload = nil
	self._flowDispatchPayload = nil
	self._flowStaticSharedMemory = nil
	self._flowStaticSharedMemoryPathfinder = nil
	self._flowWallKeyCachePathfinder = nil
	self._flowWallGridCache = nil
	self._flowWallGridHalfSize = nil
	self._flowWallGridWidth = nil

	-- Rebuild the state machine so the next flow session starts from Idle.
	self._flowPipelineStateMachine:Destroy()
	self._flowPipelineStateMachine = _CreateFlowPipelineStateMachine()
end

--[=[
    Starts movement for one entity and chooses path or shared-flow mode.
    @within MovementService
    @param entity number -- Entity id to start moving.
    @param movementMode EnemyMovementMode -- Requested movement mode from the caller.
    @param goalPosition Vector3 -- Goal position to path toward.
    @return boolean -- Whether movement started successfully.
    @return string? -- Failure reason when movement could not start.
]=]
function MovementService:StartAdvance(
	binding: TMovementActorBinding,
	movementMode: EnemyMovementMode,
	goalPosition: Vector3?
): (boolean, string?)
	local actorKey = self:_RegisterMovementBinding(binding)
	-- Clear any previous movement before selecting the next runtime mode.
	self:StopMovement(binding)

	-- Validate caller-provided goal input before selecting the movement runtime.
	if goalPosition == nil then
		return false, "MissingGoalPosition"
	end

	local resolvedMode = self:_ResolveAdvanceMode(actorKey, movementMode, goalPosition)
	if not resolvedMode then
		return false, "InvalidMovementMode"
	end

	-- Prefer shared-flow movement when the mode and configuration allow it.
	if resolvedMode == "Flow" then
		local flowResult = self:_StartFlow(actorKey, goalPosition)
		if flowResult.success then
			return true, nil
		end
		if movementMode ~= "Any" or flowResult.type ~= "FastFlowNotConfigured" then
			return false, flowResult.type
		end
	end

	-- Fall back to path movement when shared flow is unavailable.
	if self:_StartPath(actorKey, goalPosition) then
		return true, nil
	end

	return false, "PathStartFailed"
end

--[=[
    Advances movement for one entity using either the path or flow runtime.
    @within MovementService
    @param entity number -- Entity id to step.
    @param services any? -- Per-frame service payload supplied by the combat loop.
    @return boolean -- Whether movement completed for the entity on this step.
    @return string? -- Failure reason when stepping fails.
]=]
function MovementService:StepAdvance(binding: TMovementActorBinding, services: TFlowSchedulerServices?): (boolean, string?)
	local actorKey = self:_RegisterMovementBinding(binding)
	return DebugPlus.profile(STEP_ADVANCE_PROFILE_TAG, function(): (boolean, string?)
		local movementState = self._movementByActorKey[actorKey]
		if not movementState then
			return false, "MissingMovementState"
		end

		if movementState.Mode == "Path" then
			-- Path movement only needs speed refresh and promise polling.
			self:_ApplyCurrentMoveSpeed(actorKey)

			local status, reason = self:_TickPath(actorKey, movementState)
			if status == "Fail" then
				return false, reason
			end
			if status == "Success" then
				return true, nil
			end
			return false, nil
		end

		-- Flow movement runs through the separation pipeline before the per-entity solve.
		local flowMovementState = movementState :: TFlowMovementState
		return DebugPlus.profile(FLOW_STEP_ADVANCE_PROFILE_TAG, function(): (boolean, string?)
			local stepResult = self:_StepFlowAdvance(actorKey, flowMovementState, services)
			if stepResult.success then
				local outcome = stepResult.value
				if type(outcome) == "table" then
					return outcome.IsDone == true, nil
				end
				return false, nil
			end
			if stepResult.type == "FlowAdvancePending" then
				return false, nil
			end
			return false, stepResult.type
		end, MOVEMENT_PROFILING_ENABLED)
	end, MOVEMENT_PROFILING_ENABLED)
end

--[=[
    Stops active movement for one entity and clears its runtime bookkeeping.
    @within MovementService
    @param entity number -- Entity id to stop.
]=]
function MovementService:StopMovement(binding: TMovementActorBinding)
	local actorKey = self:_RegisterMovementBinding(binding)
	local movementState = self._movementByActorKey[actorKey]
	if not movementState and not self._flowGoalKeyByActorKey[actorKey] then
		return
	end

	if movementState then
		if movementState.Mode == "Path" then
			local promise = movementState.Promise
			if promise and type(promise.cancel) == "function" then
				promise:cancel()
			end
		else
			self:_StopHumanoid(actorKey)
		end
	end

	self:_ClearMovementRuntimeState(actorKey)
end

--[=[
    Stops movement for every tracked entity and resets shared-flow runtime state.
    @within MovementService
]=]
function MovementService:CleanupAll()
	local entities = self:_AcquireMovementTempArray()
	local success, err = xpcall(function()
		-- Capture movement entities first so cleanup can mutate the live maps safely.
		for actorKey in self._movementByActorKey do
			table.insert(entities, actorKey)
		end

		-- Include entities that only exist in the flow goal map and no longer have movement state.
		for actorKey in self._flowGoalKeyByActorKey do
			if not self._movementByActorKey[actorKey] then
				table.insert(entities, actorKey)
			end
		end

		-- Stop each entity through the public API so both path and flow branches unwind correctly.
		for _, actorKey in ipairs(entities) do
			local binding = self:_GetMovementBinding(actorKey)
			if binding ~= nil then
				self:StopMovement(binding)
			end
		end
	end, function(message)
		return debug.traceback(message, 2)
	end)
	self:_ReleaseMovementTempArray(entities)
	if not success then
		error(err, 0)
	end

	table.clear(self._flowActorRefsByActorKey)
	table.clear(self._movementBindingByActorKey)
	self:ResetFastFlowRuntime()
end

--[=[
    Destroys the movement service and releases its cached infrastructure.
    @within MovementService
]=]
function MovementService:Destroy()
	-- Reuse the cleanup path so all live movement stops before infrastructure teardown.
	self:CleanupAll()
	-- Release flow infrastructure after movement is clear so no solve can outlive the service.
	self:_DestroyFlowInfrastructure()

	self._flowPipelineStateMachine:Destroy()

	-- Destroy the pooled temporary-table recycler last so all callers have already released tables.
	local tempRecycler = self._movementTempTableRecycler
	if tempRecycler then
		local didDestroyRecycler, destroyRecyclerError = tempRecycler:Destroy()
		assert(didDestroyRecycler, destroyRecyclerError)
	end
	self._movementTempTableRecycler = nil
end

-- Lazily creates the recycler that pools movement temp tables across frames.
function MovementService:_GetOrCreateMovementTempTableRecycler(): TTableRecyclerLike
	local recycler = self._movementTempTableRecycler
	if recycler then
		return recycler
	end

	recycler = TableRecycler.new({
		Strict = true,
		DebugName = "CombatMovement.Temps",
	})
	self._movementTempTableRecycler = recycler
	return recycler
end

-- Acquires a pooled array for temporary movement bookkeeping.
function MovementService:_AcquireMovementTempArray(capacityHint: number?): TMovementTempEntityArray
	return self:_GetOrCreateMovementTempTableRecycler():AcquireArray(capacityHint) :: TMovementTempEntityArray
end

-- Acquires a pooled map for temporary movement bookkeeping.
function MovementService:_AcquireMovementTempMap(): TMovementTempMap
	return self:_GetOrCreateMovementTempTableRecycler():AcquireMap() :: TMovementTempMap
end

-- Releases a pooled array after the movement service has finished with it.
function MovementService:_ReleaseMovementTempArray(tbl: TMovementTempEntityArray)
	local didRelease, releaseError = self:_GetOrCreateMovementTempTableRecycler():ReleaseArray(tbl)
	assert(didRelease, releaseError)
end

-- Releases a pooled map after the movement service has finished with it.
function MovementService:_ReleaseMovementTempMap(tbl: TMovementTempMap)
	local didRelease, releaseError = self:_GetOrCreateMovementTempTableRecycler():ReleaseMap(tbl)
	assert(didRelease, releaseError)
end

-- Resolves one active runnable combat session so parallel flow jobs can tag the session owner.
function MovementService:_ResolveActiveSessionUserId(): number?
	local loopService = self._combatLoopService
	if not loopService then
		return nil
	end

	local activeSessionUserId = nil :: number?
	loopService:ForEachRunnableSession(function(userId: number)
		activeSessionUserId = userId
		return false
	end)

	return activeSessionUserId
end

-- Clears the runtime movement state for one entity and unwires any live movement-side effects.
function MovementService:_ClearMovementRuntimeState(actorKey: TMovementActorKey)
	local currentGoalKey = self._flowGoalKeyByActorKey[actorKey]
	self:_RemoveEntityFromActiveFlowGoal(actorKey, currentGoalKey)
	self._movementByActorKey[actorKey] = nil
	self._flowVelocityByActorKey[actorKey] = nil
	self._flowSettledByActorKey[actorKey] = nil
	self:_DetachSharedFlowfield(currentGoalKey)
	self._flowGoalKeyByActorKey[actorKey] = nil
	self._flowInvalidReasonByActorKey[actorKey] = nil
	self._flowRecoveredOpenCellByActorKey[actorKey] = nil
	self:_InvalidateFlowActorRefs(actorKey)
	local binding = self:_GetMovementBinding(actorKey)
	if binding ~= nil then
		binding:SetPathMoving(false)
	end
	if self._lockOnService and type(self._lockOnService.SetBoidsFacingFlatForward) == "function" then
		local entityId = self:_GetMovementEntityId(actorKey)
		if entityId ~= nil then
			self._lockOnService:SetBoidsFacingFlatForward(entityId, nil)
		end
	end
end

return MovementService
