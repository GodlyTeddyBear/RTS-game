--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Result = require(ReplicatedStorage.Utilities.Result)
local GameEvents = require(ReplicatedStorage.Events.GameEvents)

local Ok = Result.Ok

--[=[
	@class ProcessCombatTick
	Advances behavior tree and executor ticks for active combat entities.
	@server
]=]
local ProcessCombatTick = {}
ProcessCombatTick.__index = ProcessCombatTick

--[=[
	@within ProcessCombatTick
	Creates a new combat tick command.
	@return ProcessCombatTick -- Command instance used to advance combat.
]=]
function ProcessCombatTick.new()
	return setmetatable({}, ProcessCombatTick)
end

--[=[
	@within ProcessCombatTick
	Resolves the combat loop, BT policy, executor registry, and perception services.
	@param registry any -- Registry instance supplied by the context bootstrap.
	@param _name string -- Registry key used to register the command.
]=]
function ProcessCombatTick:Init(registry: any, _name: string)
	self._loopService = registry:Get("CombatLoopService")
	self._tickPolicy = registry:Get("BehaviorTreeTickPolicy")
	self._waveCompletionPolicy = registry:Get("WaveCompletionPolicy")
	self._executorRegistry = registry:Get("ExecutorRegistry")
	self._perceptionService = registry:Get("CombatPerceptionService")
	self._handleGoalReachedCommand = registry:Get("HandleGoalReached")
	self._hasSeenAliveByUser = {}
end

--[=[
	@within ProcessCombatTick
	Stores the enemy factory needed to read and mutate enemy combat state.
	@param registry any -- Registry instance used to resolve dependencies.
	@param _name string -- Registry key used to register the command.
]=]
function ProcessCombatTick:Start(registry: any, _name: string)
	self._enemyEntityFactory = registry:Get("EnemyEntityFactory")
	self._structureEntityFactory = registry:Get("StructureEntityFactory")
	self._enemyContext = registry:Get("EnemyContext")
	self._structureContext = registry:Get("StructureContext")
end

-- Runs the behavior tree phase for each alive enemy and updates its last BT tick time.
function ProcessCombatTick:_RunBehaviorTreePhase(entities: { number }, currentTime: number, factory: any, actorType: string)
	for _, entity in ipairs(entities) do
		local checkResult = self._tickPolicy:CheckFactory(factory, entity, currentTime)
		if checkResult.success then
			local behaviorTree = checkResult.value.BehaviorTree
			local facts = if actorType == "Structure"
				then self._perceptionService:BuildStructureSnapshot(entity, currentTime)
				else self._perceptionService:BuildSnapshot(entity, currentTime)
			local context = {
				Entity = entity,
				EnemyEntityFactory = self._enemyEntityFactory,
				StructureEntityFactory = self._structureEntityFactory,
				Facts = facts,
			}

			pcall(function()
				behaviorTree.TreeInstance:run(context)
			end)

			factory:UpdateBTLastTickTime(entity, currentTime)
		end
	end
end

-- Converts pending BT actions into running executors and replaces any current executor that no longer matches.
function ProcessCombatTick:_RunTransitionPhase(entities: { number }, currentTime: number, services: any, factory: any)
	for _, entity in ipairs(entities) do
		local action = factory:GetCombatAction(entity)
		if not action or not action.PendingActionId then
			continue
		end

		if action.ActionState == "Committed" then
			factory:ClearPendingAction(entity)
			continue
		end

		if action.CurrentActionId == action.PendingActionId then
			factory:ClearPendingAction(entity)
			continue
		end

		if action.CurrentActionId then
			local currentExecutor = self._executorRegistry:Get(action.CurrentActionId)
			if currentExecutor then
				pcall(function()
					currentExecutor:Cancel(entity, services)
				end)
			end
		end

		local nextExecutor = self._executorRegistry:Get(action.PendingActionId)
		if not nextExecutor then
			factory:ClearAction(entity)
			continue
		end

		local startSuccess = false
		pcall(function()
			startSuccess = nextExecutor:Start(entity, action.PendingActionData, services)
		end)

		if not startSuccess then
			factory:ClearAction(entity)
			continue
		end

		factory:StartAction(entity, action.PendingActionId, action.PendingActionData, currentTime)
	end
end

-- Ticks active executors and resolves success or failure outcomes.
function ProcessCombatTick:_RunActionPhase(entities: { number }, dt: number, services: any, factory: any)
	for _, entity in ipairs(entities) do
		local action = factory:GetCombatAction(entity)
		if not action or not action.CurrentActionId then
			continue
		end

		if action.ActionState ~= "Running" and action.ActionState ~= "Committed" then
			continue
		end

		local executor = self._executorRegistry:Get(action.CurrentActionId)
		if not executor then
			factory:ClearAction(entity)
			continue
		end

		local tickStatus = "Fail"
		pcall(function()
			tickStatus = executor:Tick(entity, dt, services)
		end)

		if tickStatus == "Success" then
			if action.CurrentActionId == "LaneAdvance" then
				local goalResult = self._handleGoalReachedCommand:Execute(entity)
				if not goalResult.success then
					Result.MentionError("Combat:ProcessCombatTick", "Failed goal-reached handling", {
						EnemyEntity = entity,
						CauseType = goalResult.type,
						CauseMessage = goalResult.message,
					}, goalResult.type)
				end
			end

			pcall(function()
				executor:Complete(entity, services)
			end)
			factory:ResetActionState(entity)
		elseif tickStatus == "Fail" then
			pcall(function()
				executor:Cancel(entity, services)
			end)
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
			self._hasSeenAliveByUser[userId] = nil
			return Ok(false)
		end

		local activeCombat = self._loopService:GetActiveCombat(userId)
		if not activeCombat or activeCombat.IsPaused then
			return Ok(false)
		end

		-- Capture one timestamp so BT gating and action execution stay aligned.
		local currentTime = os.clock()
		local aliveEntities = self._enemyEntityFactory:QueryAliveEntities()
		local activeStructures = self._structureEntityFactory:QueryActiveEntities()
		if #aliveEntities > 0 then
			self._hasSeenAliveByUser[userId] = true
		end
		-- Build the service payload shared by executors and completion handling.
		local services = {
			EnemyEntityFactory = self._enemyEntityFactory,
			StructureEntityFactory = self._structureEntityFactory,
			EnemyContext = self._enemyContext,
			StructureContext = self._structureContext,
			CurrentTime = currentTime,
			HandleGoalReached = self._handleGoalReachedCommand,
		}

		self:_RunBehaviorTreePhase(aliveEntities, currentTime, self._enemyEntityFactory, "Enemy")
		self:_RunBehaviorTreePhase(activeStructures, currentTime, self._structureEntityFactory, "Structure")
		self:_RunTransitionPhase(aliveEntities, currentTime, services, self._enemyEntityFactory)
		self:_RunTransitionPhase(activeStructures, currentTime, services, self._structureEntityFactory)
		self:_RunActionPhase(aliveEntities, dt, services, self._enemyEntityFactory)
		self:_RunActionPhase(activeStructures, dt, services, self._structureEntityFactory)

		-- Only emit wave completion after the combat has actually seen enemies on this session.
		local completion = self._waveCompletionPolicy:Check()
		if completion.Status == "WaveComplete" and self._hasSeenAliveByUser[userId] then
			self._loopService:PauseCombat(userId)
			self._hasSeenAliveByUser[userId] = nil
			GameEvents.Bus:Emit(GameEvents.Events.Run.WaveEnded, activeCombat.WaveNumber)
		end

		return Ok(true)
	end, "Combat:ProcessCombatTick")
end

return ProcessCombatTick
