--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local DebugConfig = require(ReplicatedStorage.Config.DebugConfig)
local DebugPlus = require(ReplicatedStorage.Utilities.DebugPlus)
local FastFlowHelper = require(ServerStorage.Utilities.FastFlowHelper)
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
type TEnemyEntityFactoryLike = MovementTypes.TEnemyEntityFactoryLike
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
	self._movementByEntity = {} :: { [number]: TMovementState }
	self._movementTempTableRecycler = nil
	self._fastFlowPathfinder = nil
	self._fastFlowMapping = nil
	self._sharedFlowfieldsByGoalKey = {} :: { [string]: TSharedFlowfieldEntry }
	self._flowGoalKeyByEntity = {} :: { [number]: string }
	self._activeFlowEntitiesByGoalKey = {} :: { [string]: { [number]: boolean } }
	self._flowSettledByEntity = {} :: { [number]: boolean }
	self._flowActorRefsByEntity = {} :: { [number]: TFlowActorRefs }
	self._flowVelocityByEntity = {} :: { [number]: Vector2 }
	self._flowFrameSerial = 0
	self._flowPipelineStateMachine = _CreateFlowPipelineStateMachine()
	self._flowPipelineTickId = nil :: number?
	self._flowInvalidReasonByEntity = {}
	self._flowRecoveredOpenCellByEntity = {} :: { [number]: Vector2 }
	self._flowCurrentSessionUserId = nil :: number?
	self._flowSeparationParallelRunner = nil
	self._flowSeparationManagedJob = nil
	self._flowFrameStateRecycler = nil
	self._flowFrameState = nil
	self._flowLatestParallelSolve = nil
	self._flowReusableGoalKeyByEntity = {} :: { [number]: string }
	self._flowReusableGoalPositionByEntity = {} :: { [number]: Vector3 }
	self._flowReusableGoalWorldSampleByEntity = {} :: { [number]: Vector3 }
	self._flowReusablePositionByEntity = {} :: { [number]: Vector3 }
	self._flowReusableWalkSpeedByEntity = {} :: { [number]: number }
	self._flowReusableIsSettledByEntity = {} :: { [number]: boolean }
	self._flowPublishedVelocityByEntity = {} :: { [number]: Vector2 }
	self._flowPublishedTouchedSettledNeighborByEntity = {} :: { [number]: boolean }
	self._flowPublishedGoalKeyByEntity = {} :: { [number]: string }
	self._flowPublishedGoalPositionByEntity = {} :: { [number]: Vector3 }
	self._flowPublishedGoalWorldSampleByEntity = {} :: { [number]: Vector3 }
	self._flowPublishedPositionByEntity = {} :: { [number]: Vector3 }
	self._flowPublishedWalkSpeedByEntity = {} :: { [number]: number }
	self._flowPublishedIsSettledByEntity = {} :: { [number]: boolean }
	self._flowRepresentativeStarts = {} :: { Vector3 }
	self._flowPublishedSolve = {
		TickId = 0,
		VelocityByEntity = self._flowPublishedVelocityByEntity,
		TouchedSettledNeighborByEntity = self._flowPublishedTouchedSettledNeighborByEntity,
		GoalKeyByEntity = self._flowPublishedGoalKeyByEntity,
	}
	self._flowReusableFrameState = {
		GoalKeyByEntity = self._flowReusableGoalKeyByEntity,
		GoalPositionByEntity = self._flowReusableGoalPositionByEntity,
		GoalWorldSampleByEntity = self._flowReusableGoalWorldSampleByEntity,
		PositionByEntity = self._flowReusablePositionByEntity,
		WalkSpeedByEntity = self._flowReusableWalkSpeedByEntity,
		IsSettledByEntity = self._flowReusableIsSettledByEntity,
	} :: TFlowPublishedFrameState
	self._flowPublishedFrameState = {
		GoalKeyByEntity = self._flowPublishedGoalKeyByEntity,
		GoalPositionByEntity = self._flowPublishedGoalPositionByEntity,
		GoalWorldSampleByEntity = self._flowPublishedGoalWorldSampleByEntity,
		PositionByEntity = self._flowPublishedPositionByEntity,
		WalkSpeedByEntity = self._flowPublishedWalkSpeedByEntity,
		IsSettledByEntity = self._flowPublishedIsSettledByEntity,
	} :: TFlowPublishedFrameState
	self._flowDispatchedSeparationSnapshot = nil
	self._flowDispatchedGoalKeyByEntity = nil
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

--[=[
    Wires the enemy entity factory used to read and update movement state.
    @within MovementService
    @param enemyEntityFactory any -- Enemy entity factory used by movement resolution.
]=]
function MovementService:ConfigureEnemyEntityFactory(enemyEntityFactory: TEnemyEntityFactoryLike)
	self._enemyEntityFactory = enemyEntityFactory
end

function MovementService:ConfigureEnemyInstanceFactory(enemyInstanceFactory: any)
	self._enemyInstanceFactory = enemyInstanceFactory
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
	table.clear(self._flowGoalKeyByEntity)
	table.clear(self._activeFlowEntitiesByGoalKey)
	table.clear(self._flowSettledByEntity)
	table.clear(self._flowVelocityByEntity)
	table.clear(self._flowReusableGoalKeyByEntity)
	table.clear(self._flowReusableGoalPositionByEntity)
	table.clear(self._flowReusableGoalWorldSampleByEntity)
	table.clear(self._flowReusablePositionByEntity)
	table.clear(self._flowReusableWalkSpeedByEntity)
	table.clear(self._flowReusableIsSettledByEntity)
	table.clear(self._flowPublishedVelocityByEntity)
	table.clear(self._flowPublishedTouchedSettledNeighborByEntity)
	table.clear(self._flowPublishedGoalKeyByEntity)
	table.clear(self._flowPublishedGoalPositionByEntity)
	table.clear(self._flowPublishedGoalWorldSampleByEntity)
	table.clear(self._flowPublishedPositionByEntity)
	table.clear(self._flowPublishedWalkSpeedByEntity)
	table.clear(self._flowPublishedIsSettledByEntity)

	-- Reset the pipeline bookkeeping and invalidate any stuck recovery state.
	table.clear(self._flowRepresentativeStarts)
	self._flowPipelineTickId = nil
	table.clear(self._flowInvalidReasonByEntity)
	table.clear(self._flowRecoveredOpenCellByEntity)
	self._flowLatestParallelSolve = nil
	self._flowDispatchedGoalKeyByEntity = nil
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
    @return boolean -- Whether movement started successfully.
    @return string? -- Failure reason when movement could not start.
]=]
function MovementService:StartAdvance(entity: number, movementMode: EnemyMovementMode): (boolean, string?)
	-- Clear any previous movement before selecting the next runtime mode.
	self:StopMovement(entity)

	-- Resolve the target goal and confirm the requested movement mode is valid.
	local pathState = self._enemyEntityFactory:GetPathState(entity)
	if not pathState or not pathState.GoalPosition then
		return false, "MissingGoalPosition"
	end

	local resolvedMode = self:_ResolveAdvanceMode(movementMode, pathState.GoalPosition)
	if not resolvedMode then
		return false, "InvalidMovementMode"
	end

	-- Prefer shared-flow movement when the mode and configuration allow it.
	if resolvedMode == "Flow" then
		local flowResult = self:_StartFlow(entity, pathState.GoalPosition)
		if flowResult.success then
			return true, nil
		end
		if movementMode ~= "Any" or flowResult.type ~= "FastFlowNotConfigured" then
			return false, flowResult.type
		end
	end

	-- Fall back to path movement when shared flow is unavailable.
	if self:_StartPath(entity, pathState.GoalPosition) then
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
function MovementService:StepAdvance(entity: number, services: TFlowSchedulerServices?): (boolean, string?)
	return DebugPlus.profile(STEP_ADVANCE_PROFILE_TAG, function(): (boolean, string?)
		local movementState = self._movementByEntity[entity]
		if not movementState then
			return false, "MissingMovementState"
		end

		if movementState.Mode == "Path" then
			-- Path movement only needs speed refresh and promise polling.
			self:_ApplyCurrentMoveSpeed(entity)

			local status, reason = self:_TickPath(entity, movementState)
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
			local stepResult = self:_StepFlowAdvance(entity, flowMovementState, services)
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
function MovementService:StopMovement(entity: number)
	local movementState = self._movementByEntity[entity]
	if not movementState and not self._flowGoalKeyByEntity[entity] then
		return
	end

	if movementState then
		if movementState.Mode == "Path" then
			local promise = movementState.Promise
			if promise and type(promise.cancel) == "function" then
				promise:cancel()
			end
		else
			self:_StopHumanoid(entity)
		end
	end

	self:_ClearMovementRuntimeState(entity)
end

--[=[
    Stops movement for every tracked entity and resets shared-flow runtime state.
    @within MovementService
]=]
function MovementService:CleanupAll()
	local entities = self:_AcquireMovementTempArray()
	local success, err = xpcall(function()
		-- Capture movement entities first so cleanup can mutate the live maps safely.
		for entityId in self._movementByEntity do
			table.insert(entities, entityId)
		end

		-- Include entities that only exist in the flow goal map and no longer have movement state.
		for entityId in self._flowGoalKeyByEntity do
			if not self._movementByEntity[entityId] then
				table.insert(entities, entityId)
			end
		end

		-- Stop each entity through the public API so both path and flow branches unwind correctly.
		for _, entityId in ipairs(entities) do
			self:StopMovement(entityId)
		end
	end, function(message)
		return debug.traceback(message, 2)
	end)
	self:_ReleaseMovementTempArray(entities)
	if not success then
		error(err, 0)
	end

	table.clear(self._flowActorRefsByEntity)
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
function MovementService:_ClearMovementRuntimeState(entity: number)
	local currentGoalKey = self._flowGoalKeyByEntity[entity]
	self:_RemoveEntityFromActiveFlowGoal(entity, currentGoalKey)
	self._movementByEntity[entity] = nil
	self._flowVelocityByEntity[entity] = nil
	self._flowSettledByEntity[entity] = nil
	self:_DetachSharedFlowfield(currentGoalKey)
	self._flowGoalKeyByEntity[entity] = nil
	self._flowInvalidReasonByEntity[entity] = nil
	self._flowRecoveredOpenCellByEntity[entity] = nil
	self:_InvalidateFlowActorRefs(entity)
	self._enemyEntityFactory:SetPathMoving(entity, false)
	if self._lockOnService and type(self._lockOnService.SetBoidsFacingFlatForward) == "function" then
		self._lockOnService:SetBoidsFacingFlatForward(entity, nil)
	end
end

return MovementService
