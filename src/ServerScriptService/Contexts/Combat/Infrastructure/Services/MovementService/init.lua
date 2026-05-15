--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CombatMovementConfig = require(ReplicatedStorage.Contexts.Combat.Config.CombatMovementConfig)
local FastFlowHelper = require(ReplicatedStorage.Utilities.FastFlowHelper)
local MovementTypes = require(script.Types)

type EnemyMovementMode = MovementTypes.EnemyMovementMode
type TMovementState = MovementTypes.TMovementState
type TAdvanceStatus = MovementTypes.TAdvanceStatus
type TAdvanceFrameResult = MovementTypes.TAdvanceFrameResult
type TSharedFlowfieldEntry = MovementTypes.TSharedFlowfieldEntry
type TFlowSeparationRuntime = MovementTypes.TFlowSeparationRuntime
type TFlowActorRefs = MovementTypes.TFlowActorRefs
type TFastFlowProfileCounters = MovementTypes.TFastFlowProfileCounters
type TFlowVelocitySolveInput = MovementTypes.TFlowVelocitySolveInput
type TFlowVelocityAsyncState = MovementTypes.TFlowVelocityAsyncState
type TFlowSeparationPairSnapshotBuildAsyncState = MovementTypes.TFlowSeparationPairSnapshotBuildAsyncState

--[=[
	@class MovementService
	Owns Combat enemy movement runtime coordination for pathfinding- and flowfield-based advance.
	@server
]=]
local MovementService = {}
MovementService.__index = MovementService

require(script.ActorRefs)(MovementService)
require(script.PathMovement)(MovementService)
require(script.FastFlowProfiling)(MovementService)
require(script.SharedFlowfields)(MovementService)
require(script.FlowSeparation)(MovementService)
require(script.FlowMovement)(MovementService)

function MovementService.new()
	local self = setmetatable({}, MovementService)
	self._movementByEntity = {} :: { [number]: TMovementState }
	self._advanceFrameResultByEntity = {} :: { [number]: TAdvanceFrameResult }
	self._movementFrameId = 0
	self._fastFlowPathfinder = nil
	self._fastFlowMapping = nil
	self._lastFastFlowEndpointDiagnosticKey = nil :: string?
	self._flowVelByEntity = {} :: { [number]: Vector2 }
	self._flowSteeringRepairAtClockByEntity = {} :: { [number]: number }
	self._flowSeparationRuntime = nil :: TFlowSeparationRuntime?
	self._sharedFlowfieldsByGoalKey = {} :: { [string]: TSharedFlowfieldEntry }
	self._flowGoalKeyByEntity = {} :: { [number]: string }
	self._activeFlowEntitiesByGoalKey = {} :: { [string]: { [number]: boolean } }
	self._flowSettledByEntity = {} :: { [number]: boolean }
	self._flowSettleAnchorGoalKeyByEntity = {} :: { [number]: string }
	self._flowActorRefsByEntity = {} :: { [number]: TFlowActorRefs }
	self._flowSeparationParallelRunner = nil
	self._flowSeparationPairAsyncState = nil
	self._flowSeparationPairSnapshotBuildAsyncState = nil :: TFlowSeparationPairSnapshotBuildAsyncState?
	self._flowVelocityAsyncState = nil :: TFlowVelocityAsyncState?
	self._fastFlowProfileCounters = nil :: TFastFlowProfileCounters?
	self._lastFastFlowProfileLogAt = 0
	return self
end

function MovementService:Init(registry: any, _name: string)
	self._registry = registry
end


function MovementService:Start()
end


function MovementService:ConfigureEnemyEntityFactory(enemyEntityFactory: any)
	self._enemyEntityFactory = enemyEntityFactory
end


function MovementService:ConfigureLockOnService(lockOnService: any)
	self._lockOnService = lockOnService
end


function MovementService:ConfigureFastFlow(pathfinder: any?, mapping: FastFlowHelper.TFlowGridMapping?)
	self._fastFlowPathfinder = pathfinder
	self._fastFlowMapping = mapping
end


function MovementService:ResetFastFlowRuntime()
	table.clear(self._flowVelByEntity)
	table.clear(self._flowSteeringRepairAtClockByEntity)
	table.clear(self._sharedFlowfieldsByGoalKey)
	table.clear(self._flowGoalKeyByEntity)
	table.clear(self._activeFlowEntitiesByGoalKey)
	table.clear(self._flowSettledByEntity)
	table.clear(self._flowSettleAnchorGoalKeyByEntity)
	self:_DestroyFlowSeparationParallelRunner()
	self:_ClearFlowSeparationPairAsyncState()
	self:_ClearFlowSeparationPairSnapshotBuildAsyncState()
	self:_ClearFlowVelocityAsyncState()
	self._flowSeparationRuntime = nil
	self._lastFastFlowEndpointDiagnosticKey = nil
end


function MovementService:ConfigureFlowfieldDebugRenderer(renderer: ((any, FastFlowHelper.TFlowGridMapping, Vector3) -> ())?)
	self._flowfieldDebugRenderer = renderer
end


function MovementService:BeginCombatFrame(sessionUserId: number, currentTime: number)
	local separationRuntime = self:_GetOrCreateFlowSeparationRuntime()
	separationRuntime.SessionUserId = sessionUserId
	separationRuntime.CurrentTime = currentTime
	self:_ResetFastFlowProfileCounters()
end


function MovementService:EndCombatFrame(_sessionUserId: number)
	self:_EmitFastFlowProfileCounters()
	self._fastFlowProfileCounters = nil
end


function MovementService:TickMovementFrame(_dt: number)
	self._movementFrameId += 1

	local sepConfig = CombatMovementConfig.FLOW_SOFT_SEPARATION

	-- This method runs inside the scheduler, so it must never yield while staging async movement work.
	local frameResultsByEntity: { [number]: { Status: TAdvanceStatus, Reason: string? } } =
		self:_ApplyCompletedFlowVelocityAsyncResult(sepConfig) or {}

	if next(self._movementByEntity) == nil then
		return
	end

	local activeEntities = {}
	for entity in self._movementByEntity do
		table.insert(activeEntities, entity)
	end

	local pendingFlowVelocityInputs = {}

	for _, entity in ipairs(activeEntities) do
		local status, reason, pendingVelocityInput = self:_TickAdvanceInternal(entity)
		if pendingVelocityInput ~= nil then
			table.insert(pendingFlowVelocityInputs, pendingVelocityInput)
			if frameResultsByEntity[entity] == nil then
				frameResultsByEntity[entity] = {
					Status = "Running",
					Reason = nil,
				}
			end
		else
			frameResultsByEntity[entity] = {
				Status = status,
				Reason = reason,
			}
		end
	end

	if #pendingFlowVelocityInputs > 0 then
		local localResultsByEntity: { [number]: { Status: TAdvanceStatus, Reason: string? } }? = nil

		if self:_IsFlowSeparationParallelEnabled(sepConfig) and self:_IsFlowVelocityParallelAsyncEnabled(sepConfig) then
			local velocitySnapshot = self:_CreateFlowVelocitySolveSnapshot(pendingFlowVelocityInputs)
			local dispatchStatus = self:_DispatchFlowVelocityWithParallelQueryAsync(velocitySnapshot, sepConfig)
			if dispatchStatus == "BelowThreshold" or dispatchStatus == "Failed" then
				localResultsByEntity = self:_ResolvePendingFlowVelocityMoves(pendingFlowVelocityInputs)
			elseif dispatchStatus == "InFlight" and not self:_ShouldUsePreviousFlowVelocityParallelResult(sepConfig) then
				localResultsByEntity = self:_ResolvePendingFlowVelocityMoves(pendingFlowVelocityInputs)
			end
		else
			localResultsByEntity = self:_ResolvePendingFlowVelocityMoves(pendingFlowVelocityInputs)
		end

		if localResultsByEntity ~= nil then
			for entity, result in localResultsByEntity do
				frameResultsByEntity[entity] = result
			end
		end
	end

	for entity, result in frameResultsByEntity do
		self._advanceFrameResultByEntity[entity] = {
			Status = result.Status,
			Reason = result.Reason,
			FrameId = self._movementFrameId,
		}
	end
end


function MovementService:GetAdvanceStatus(entity: number): (TAdvanceStatus, string?)
	local frameResult = self._advanceFrameResultByEntity[entity]
	if frameResult ~= nil and frameResult.FrameId == self._movementFrameId then
		return frameResult.Status, frameResult.Reason
	end

	if self._movementByEntity[entity] ~= nil then
		return "Running", nil
	end

	return "Fail", "MissingMovementState"
end


function MovementService:StartAdvance(entity: number, movementMode: EnemyMovementMode): (boolean, string?)
	self:StopMovement(entity)

	local pathState = self._enemyEntityFactory:GetPathState(entity)
	if pathState == nil or pathState.GoalPosition == nil then
		return false, "MissingGoalPosition"
	end

	local resolvedMode = self:_ResolveAdvanceMode(movementMode, pathState.GoalPosition)
	if resolvedMode == nil then
		return false, "InvalidMovementMode"
	end

	if resolvedMode == "Flow" then
		local startedFlow, flowReason = self:_StartFlow(entity, pathState.GoalPosition)
		if startedFlow then
			return true, nil
		end
		if movementMode ~= "Any" or flowReason ~= "FastFlowNotConfigured" then
			return false, if flowReason ~= nil then flowReason else "FlowStartFailed"
		end
	end

	if self:_StartPath(entity, pathState.GoalPosition) then
		return true, nil
	end

	return false, "PathStartFailed"
end


function MovementService:_TickAdvanceInternal(entity: number): ("Running" | "Success" | "Fail", string?, TFlowVelocitySolveInput?)
	local movementState = self._movementByEntity[entity]
	if movementState == nil then
		return "Fail", "MissingMovementState", nil
	end

	if movementState.Mode == "Flow" then
		return self:_TickFlow(entity, movementState)
	end

	self:_ApplyCurrentMoveSpeed(entity)

	local status, reason = self:_TickPath(entity, movementState)
	return status, reason, nil
end


function MovementService:TickAdvance(entity: number): ("Running" | "Success" | "Fail", string?)
	local status, reason, pendingVelocityInput = self:_TickAdvanceInternal(entity)
	if pendingVelocityInput ~= nil then
		local resultsByEntity = self:_ResolvePendingFlowVelocityMoves({ pendingVelocityInput })
		local result = resultsByEntity[pendingVelocityInput.Entity]
		if result ~= nil then
			return result.Status, result.Reason
		end
	end

	return status, reason
end


function MovementService:StopMovement(entity: number)
	local movementState = self._movementByEntity[entity]
	if movementState == nil and self._flowSettleAnchorGoalKeyByEntity[entity] == nil then
		self._advanceFrameResultByEntity[entity] = nil
		return
	end

	if movementState ~= nil then
		if movementState.Mode == "Path" then
			local promise = movementState.Promise
			if promise ~= nil and type(promise.cancel) == "function" then
				promise:cancel()
			end
		else
			self:_StopHumanoid(entity)
		end
	end

	self._advanceFrameResultByEntity[entity] = nil
	self:_ClearMovementRuntimeState(entity)
end


function MovementService:CleanupAll()
	local entities = {}
	for entityId in self._movementByEntity do
		table.insert(entities, entityId)
	end

	for entityId in self._flowSettleAnchorGoalKeyByEntity do
		if self._movementByEntity[entityId] == nil then
			table.insert(entities, entityId)
		end
	end

	for _, entityId in ipairs(entities) do
		self:StopMovement(entityId)
	end

	table.clear(self._flowVelByEntity)
	table.clear(self._flowSteeringRepairAtClockByEntity)
	table.clear(self._sharedFlowfieldsByGoalKey)
	table.clear(self._flowGoalKeyByEntity)
	table.clear(self._activeFlowEntitiesByGoalKey)
	table.clear(self._flowSettledByEntity)
	table.clear(self._flowSettleAnchorGoalKeyByEntity)
	table.clear(self._flowActorRefsByEntity)
	table.clear(self._advanceFrameResultByEntity)
	self:_DestroyFlowSeparationParallelRunner()
	self:_ClearFlowSeparationPairAsyncState()
	self:_ClearFlowSeparationPairSnapshotBuildAsyncState()
	self:_ClearFlowVelocityAsyncState()
	self._flowSeparationRuntime = nil
end


return MovementService
