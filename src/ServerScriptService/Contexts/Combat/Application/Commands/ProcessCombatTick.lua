--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Result = require(ReplicatedStorage.Utilities.Result)
local BaseCommand = require(ReplicatedStorage.Utilities.BaseApplication.BaseCommand)

local Ok = Result.Ok

--[=[
	@class ProcessCombatTick
	Advances behavior tree and executor ticks for active combat entities.
	@server
]=]
local ProcessCombatTick = {}
ProcessCombatTick.__index = ProcessCombatTick
setmetatable(ProcessCombatTick, BaseCommand)

local function _cloneActionState(actionState: any): any
	if actionState == nil then
		return {
			CurrentActionId = nil,
			ActionState = "Idle",
			ActionData = nil,
			PendingActionId = nil,
			PendingActionData = nil,
			StartedAt = nil,
			FinishedAt = nil,
		}
	end

	return {
		CurrentActionId = actionState.CurrentActionId,
		ActionState = actionState.ActionState or "Idle",
		ActionData = actionState.ActionData,
		PendingActionId = actionState.PendingActionId,
		PendingActionData = actionState.PendingActionData,
		StartedAt = actionState.StartedAt or actionState.ActionStartedAt,
		FinishedAt = actionState.FinishedAt,
	}
end

local function _mentionRuntimeFailure(scope: string, message: string, actorType: string, entity: number, failure: any)
	Result.MentionError(scope, message, {
		ActorType = actorType,
		Entity = entity,
		CauseType = failure.type,
		CauseMessage = failure.message,
	}, failure.type)
end

--[=[
	@within ProcessCombatTick
	Creates a new combat tick command.
	@return ProcessCombatTick -- Command instance used to advance combat.
]=]
function ProcessCombatTick.new()
	local self = BaseCommand.new("Combat", "ProcessCombatTick")
	return setmetatable(self, ProcessCombatTick)
end

--[=[
	@within ProcessCombatTick
	Resolves the combat loop, behavior runtime, wave-completion policy, and perception services.
	@param registry any -- Registry instance supplied by the context bootstrap.
	@param _name string -- Registry key used to register the command.
]=]
function ProcessCombatTick:Init(registry: any, _name: string)
	self:_RequireDependencies(registry, {
		_loopService = "CombatLoopService",
		_behaviorRuntimeService = "CombatBehaviorRuntimeService",
		_combatHitResolutionService = "CombatHitResolutionService",
		_perceptionService = "CombatPerceptionService",
		_handleGoalReachedCommand = "HandleGoalReached",
		_hitboxService = "HitboxService",
		_movementService = "MovementService",
		_projectileService = "ProjectileService",
	})
end

--[=[
	@within ProcessCombatTick
	Stores the enemy factory needed to read and mutate enemy combat state.
	@param registry any -- Registry instance used to resolve dependencies.
	@param _name string -- Registry key used to register the command.
]=]
function ProcessCombatTick:Start(registry: any, _name: string)
	self:_RequireDependencies(registry, {
		_enemyEntityFactory = "EnemyEntityFactory",
		_structureEntityFactory = "StructureEntityFactory",
		_baseEntityFactory = "BaseEntityFactory",
		_enemyContext = "EnemyContext",
		_structureContext = "StructureContext",
		_baseContext = "BaseContext",
	})
end

-- Runs the behavior tree phase for each active entity and updates its last behavior tick time.
function ProcessCombatTick:_RunBehaviorTreePhase(
	entities: { number },
	currentTime: number,
	factory: any,
	actorType: string
)
	for _, entity in ipairs(entities) do
		-- Skip entities without a ready tree so the tick loop only evaluates valid combatants.
		local behaviorTree = self._behaviorRuntimeService:GetReadyBehaviorTree(factory, entity, currentTime)
		if behaviorTree == nil then
			continue
		end

		-- Build the perception snapshot that the behavior tree uses to make its decision.
		local facts = if actorType == "Structure"
			then self._perceptionService:BuildStructureSnapshot(entity, currentTime)
			else self._perceptionService:BuildSnapshot(entity, currentTime)
		local context = {
			Entity = entity,
			ActionFactory = factory,
			EnemyEntityFactory = self._enemyEntityFactory,
			StructureEntityFactory = self._structureEntityFactory,
			Facts = facts,
		}

		local didRun, runError = pcall(function()
			behaviorTree.TreeInstance:run(context)
		end)
		if not didRun then
			Result.MentionError("Combat:ProcessCombatTick", "Behavior tree evaluation failed", {
				ActorType = actorType,
				Entity = entity,
				CauseMessage = runError,
			}, "BehaviorTreeRunFailed")
		end

		factory:UpdateBTLastTickTime(entity, currentTime)
	end
end

-- Starts or replaces pending actions through the shared behavior runtime.
function ProcessCombatTick:_RunTransitionPhase(
	entities: { number },
	currentTime: number,
	services: any,
	factory: any,
	actorType: string
)
	for _, entity in ipairs(entities) do
		-- Read the current action state once so transition handling works on a stable snapshot.
		local actionState = _cloneActionState(factory:GetCombatAction(entity))
		local startResult = self._behaviorRuntimeService:StartPendingAction(entity, actionState, {
			Services = services,
		})

		-- Drop entities that the runtime rejected before mutating any stored action state.
		if not startResult.success then
			_mentionRuntimeFailure(
				"Combat:ProcessCombatTick",
				"Behavior runtime failed while starting a pending action",
				actorType,
				entity,
				startResult
			)
			factory:ClearAction(entity)
			continue
		end

		-- Preserve no-change and blocked transitions without disturbing the current action state.
		local status = startResult.value.Status
		if status == "NoAction" or status == "Blocked" then
			continue
		end

		-- Clear pending fields when the runtime reports that nothing should advance yet.
		if status == "NoChange" then
			actionState.PendingActionId = nil
			actionState.PendingActionData = nil
			factory:SetCombatAction(entity, actionState)
			continue
		end

		-- Remove invalid or failed transitions so the entity can re-enter a clean decision state.
		if status == "MissingAction" or status == "FailedToStart" then
			factory:ClearAction(entity)
			continue
		end

		-- Commit the transition only after the runtime confirms the new action can start.
		local commitResult = self._behaviorRuntimeService:CommitStartedAction(actionState, startResult.value, currentTime)
		if commitResult.Status == "Committed" then
			factory:SetCombatAction(entity, actionState)
			continue
		end

		Result.MentionError("Combat:ProcessCombatTick", "Behavior runtime returned an invalid commit transition", {
			ActorType = actorType,
			Entity = entity,
			StartStatus = status,
			CommitStatus = commitResult.Status,
		}, "InvalidBehaviorCommit")
		factory:ClearAction(entity)
	end
end

-- Ticks current actions through the shared behavior runtime and resolves terminal results.
function ProcessCombatTick:_RunActionPhase(
	entities: { number },
	dt: number,
	services: any,
	factory: any,
	actorType: string
)
	for _, entity in ipairs(entities) do
		-- Tick a cloned action state so runtime mutations stay isolated until the result is accepted.
		local actionState = _cloneActionState(factory:GetCombatAction(entity))
		local tickResult = self._behaviorRuntimeService:TickCurrentAction(entity, actionState, {
			DeltaTime = dt,
			Services = services,
		})

		-- Clear entities whose current action can no longer progress this frame.
		if not tickResult.success then
			_mentionRuntimeFailure(
				"Combat:ProcessCombatTick",
				"Behavior runtime failed while ticking the current action",
				actorType,
				entity,
				tickResult
			)
			factory:ClearAction(entity)
			continue
		end

		-- Route completed advance actions through the goal handler before resolving the runtime result.
		local runtimeTick = tickResult.value
		if runtimeTick.Status == "Success" and runtimeTick.ActionId == "Advance" then
			local goalResult = self._handleGoalReachedCommand:Execute(entity)
			if not goalResult.success then
				Result.MentionError("Combat:ProcessCombatTick", "Failed goal-reached handling", {
					EnemyEntity = entity,
					CauseType = goalResult.type,
					CauseMessage = goalResult.message,
				}, goalResult.type)
			else
				continue
			end
		end

		-- Commit finished actions only after the runtime returns a valid resolution transition.
		local resolveResult =
			self._behaviorRuntimeService:ResolveFinishedAction(actionState, runtimeTick, services.CurrentTime)
		if resolveResult.Status == "Resolved" then
			factory:SetCombatAction(entity, actionState)
			continue
		end

		if resolveResult.Status == "InvalidResult" then
			Result.MentionError("Combat:ProcessCombatTick", "Behavior runtime returned an invalid resolve transition", {
				ActorType = actorType,
				Entity = entity,
				ActionId = runtimeTick.ActionId,
				TickStatus = runtimeTick.Status,
			}, "InvalidBehaviorResolve")
			factory:ClearAction(entity)
		end
	end
end

--[=[
	@within ProcessCombatTick
	Advances combat for one active user session and emits wave completion when all enemies are resolved.
	@param userId number -- User id whose combat session should advance.
	@param dt number -- Frame delta time for the current tick.
	@return Result.Result<boolean> -- Success confirmation or a typed combat error.
]=]
function ProcessCombatTick:Execute(userId: number, dt: number): Result.Result<boolean>
	return Result.Catch(function()
		-- Skip inactive or paused sessions so the scheduler can safely keep iterating.
		if not self._loopService:IsActive(userId) then
			return Ok(false)
		end

		local activeCombat = self._loopService:GetActiveCombat(userId)
		if not activeCombat or activeCombat.IsPaused then
			return Ok(false)
		end

		-- Capture one timestamp so tree evaluation and runtime dispatch stay aligned.
		local currentTime = os.clock()
		local aliveEntities = self._enemyEntityFactory:QueryAliveEntities()
		local activeStructures = self._structureEntityFactory:QueryActiveEntities()

		-- Build the shared service bag once so runtime dispatch is consistent across all entities.
		local services = {
			EnemyEntityFactory = self._enemyEntityFactory,
			StructureEntityFactory = self._structureEntityFactory,
			BaseEntityFactory = self._baseEntityFactory,
			CombatPerceptionService = self._perceptionService,
			EnemyContext = self._enemyContext,
			StructureContext = self._structureContext,
			BaseContext = self._baseContext,
			CurrentTime = currentTime,
			HandleGoalReached = self._handleGoalReachedCommand,
			HitboxService = self._hitboxService,
			MovementService = self._movementService,
			CombatHitResolutionService = self._combatHitResolutionService,
			ProjectileService = self._projectileService,
		}

		-- Run the three combat phases in order so evaluation, transition, and action ticks stay aligned.
		self:_RunBehaviorTreePhase(aliveEntities, currentTime, self._enemyEntityFactory, "Enemy")
		self:_RunBehaviorTreePhase(activeStructures, currentTime, self._structureEntityFactory, "Structure")
		self:_RunTransitionPhase(aliveEntities, currentTime, services, self._enemyEntityFactory, "Enemy")
		self:_RunTransitionPhase(activeStructures, currentTime, services, self._structureEntityFactory, "Structure")
		self:_RunActionPhase(aliveEntities, dt, services, self._enemyEntityFactory, "Enemy")
		self:_RunActionPhase(activeStructures, dt, services, self._structureEntityFactory, "Structure")

		return Ok(true)
	end, self:_Label())
end

return ProcessCombatTick
