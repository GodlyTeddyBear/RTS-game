--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FastFlowHelper = require(ReplicatedStorage.Utilities.FastFlowHelper)
local StateMachine = require(ReplicatedStorage.Utilities.StateMachine)
local MovementTypes = require(script.Types)

type EnemyMovementMode = MovementTypes.EnemyMovementMode
type TMovementState = MovementTypes.TMovementState
type TSharedFlowfieldEntry = MovementTypes.TSharedFlowfieldEntry
type TFlowActorRefs = MovementTypes.TFlowActorRefs
type TFlowPipelineState = MovementTypes.TFlowPipelineState

local FLOW_PIPELINE_TRANSITIONS: { [TFlowPipelineState]: { [TFlowPipelineState]: boolean } } = {
	Idle = {
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

local function _CreateFlowPipelineStateMachine()
	return StateMachine.new({
		InitialState = "Idle" :: TFlowPipelineState,
		Transitions = FLOW_PIPELINE_TRANSITIONS,
		ErrorType = "IllegalFlowPipelineTransition",
		ErrorMessage = "Flow pipeline transition is not allowed",
		ErrorDataBuilder = function(fromState: TFlowPipelineState, toState: TFlowPipelineState)
			return {
				From = fromState,
				To = toState,
			}
		end,
	})
end

local MovementService = {}
MovementService.__index = MovementService

require(script.ActorRefs)(MovementService)
require(script.PathMovement)(MovementService)
require(script.SharedFlowfields)(MovementService)
require(script.FlowFrameState)
require(script.FlowSnapshot)(MovementService)
require(script.FlowPipeline)(MovementService)
require(script.FlowMovement)(MovementService)

function MovementService.new()
	local self = setmetatable({}, MovementService)
	self._movementByEntity = {} :: { [number]: TMovementState }
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
	self._flowCurrentSessionUserId = nil :: number?
	self._flowSeparationParallelRunner = nil
	self._flowSeparationManagedJob = nil
	self._flowFrameStateRecycler = nil
	self._flowFrameState = nil
	self._flowLatestParallelSolve = nil
	self._flowReusableGoalKeyByEntity = {} :: { [number]: string }
	self._flowPublishedVelocityByEntity = {} :: { [number]: Vector2 }
	self._flowPublishedTouchedSettledNeighborByEntity = {} :: { [number]: boolean }
	self._flowPublishedGoalKeyByEntity = {} :: { [number]: string }
	self._flowDispatchedSeparationSnapshot = nil
	self._flowDispatchedTouchedSettledNeighborByEntity = nil
	self._flowDispatchedGoalKeyByEntity = nil
	self._flowWallKeyCachePathfinder = nil
	self._flowWallPackedKeys = nil
	self._flowWallGridHalfSize = nil
	return self
end

function MovementService:Init(registry: any, _name: string)
	self._registry = registry
	self._combatLoopService = registry:Get("CombatLoopService")
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
	self._flowWallKeyCachePathfinder = nil
	self._flowWallPackedKeys = nil
	self._flowWallGridHalfSize = nil
end

function MovementService:ConfigureFlowfieldDebugRenderer(renderer: ((any, FastFlowHelper.TFlowGridMapping, Vector3) -> ())?)
	self._flowfieldDebugRenderer = renderer
end

function MovementService:FinalizeAdvanceFrame()
end

function MovementService:ResetFastFlowRuntime()
	self:_ReleaseFlowLatestParallelSolve()
	self:_ReleaseFlowDispatchedSeparationSnapshot()
	table.clear(self._sharedFlowfieldsByGoalKey)
	table.clear(self._flowGoalKeyByEntity)
	table.clear(self._activeFlowEntitiesByGoalKey)
	table.clear(self._flowSettledByEntity)
	table.clear(self._flowVelocityByEntity)
	table.clear(self._flowReusableGoalKeyByEntity)
	table.clear(self._flowPublishedVelocityByEntity)
	table.clear(self._flowPublishedTouchedSettledNeighborByEntity)
	table.clear(self._flowPublishedGoalKeyByEntity)
	self._flowPipelineTickId = nil
	table.clear(self._flowInvalidReasonByEntity)
	self._flowLatestParallelSolve = nil
	self._flowDispatchedTouchedSettledNeighborByEntity = nil
	self._flowDispatchedGoalKeyByEntity = nil
	self._flowWallKeyCachePathfinder = nil
	self._flowWallPackedKeys = nil
	self._flowWallGridHalfSize = nil
	self:_DestroyFlowSeparationRunner()
	self._flowPipelineStateMachine:Destroy()
	self._flowPipelineStateMachine = _CreateFlowPipelineStateMachine()
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

function MovementService:StepAdvance(entity: number, services: any?): (boolean, string?)
	local movementState = self._movementByEntity[entity]
	if movementState == nil then
		return false, "MissingMovementState"
	end

	if movementState.Mode == "Path" then
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

	return self:_StepFlowAdvance(entity, movementState, services)
end

function MovementService:StopMovement(entity: number)
	local movementState = self._movementByEntity[entity]
	if movementState == nil and self._flowGoalKeyByEntity[entity] == nil then
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

	self:_ClearMovementRuntimeState(entity)
end

function MovementService:CleanupAll()
	local entities = {}
	for entityId in self._movementByEntity do
		table.insert(entities, entityId)
	end

	for entityId in self._flowGoalKeyByEntity do
		if self._movementByEntity[entityId] == nil then
			table.insert(entities, entityId)
		end
	end

	for _, entityId in ipairs(entities) do
		self:StopMovement(entityId)
	end

	table.clear(self._flowActorRefsByEntity)
	self:ResetFastFlowRuntime()
end

function MovementService:_ResolveActiveSessionUserId(): number?
	local loopService = self._combatLoopService
	if loopService == nil then
		return nil
	end

	local activeSessionUserId = nil :: number?
	loopService:ForEachRunnableSession(function(userId: number)
		activeSessionUserId = userId
		return false
	end)

	return activeSessionUserId
end

function MovementService:_ClearMovementRuntimeState(entity: number)
	local currentGoalKey = self._flowGoalKeyByEntity[entity]
	self:_RemoveEntityFromActiveFlowGoal(entity, currentGoalKey)
	self._movementByEntity[entity] = nil
	self._flowVelocityByEntity[entity] = nil
	self._flowSettledByEntity[entity] = nil
	self:_DetachSharedFlowfield(currentGoalKey)
	self._flowGoalKeyByEntity[entity] = nil
	self:_InvalidateFlowActorRefs(entity)
	self._enemyEntityFactory:SetPathMoving(entity, false)
	if self._lockOnService ~= nil and type(self._lockOnService.SetBoidsFacingFlatForward) == "function" then
		self._lockOnService:SetBoidsFacingFlatForward(entity, nil)
	end
end

return MovementService
