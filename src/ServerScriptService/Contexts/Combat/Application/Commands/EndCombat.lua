--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Result = require(ReplicatedStorage.Utilities.Result)

local Ok = Result.Ok

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

local function _cancelRuntimeAction(scope: string, behaviorRuntimeService: any, entity: number, actionState: any, services: any)
	local cancelResult = behaviorRuntimeService:CancelCurrentAction(entity, actionState, {
		Services = services,
	})
	if cancelResult.success then
		return
	end

	Result.MentionError(scope, "Behavior runtime failed while cancelling an active action during cleanup", {
		Entity = entity,
		CauseType = cancelResult.type,
		CauseMessage = cancelResult.message,
	}, cancelResult.type)
end

--[=[
	@class EndCombat
	Cancels active executors and clears active combat sessions.
	@server
]=]
local EndCombat = {}
EndCombat.__index = EndCombat

--[=[
	@within EndCombat
	Creates a new combat teardown command.
	@return EndCombat -- Command instance used to end combat sessions.
]=]
function EndCombat.new()
	return setmetatable({}, EndCombat)
end

--[=[
	@within EndCombat
	Resolves the combat loop, behavior runtime, and enemy factory dependencies.
	@param registry any -- Registry instance supplied by the context bootstrap.
	@param _name string -- Registry key used to register the command.
]=]
function EndCombat:Init(registry: any, _name: string)
	self._loopService = registry:Get("CombatLoopService")
	self._behaviorRuntimeService = registry:Get("CombatBehaviorRuntimeService")
	self._combatHitResolutionService = registry:Get("CombatHitResolutionService")
	self._hitboxService = registry:Get("HitboxService")
	self._lockOnService = registry:Get("LockOnService")
	self._movementService = registry:Get("MovementService")
end

--[=[
	@within EndCombat
	Stores the enemy factory needed to clear combat-owned state.
	@param registry any -- Registry instance used to resolve dependencies.
	@param _name string -- Registry key used to register the command.
]=]
function EndCombat:Start(registry: any, _name: string)
	self._enemyEntityFactory = registry:Get("EnemyEntityFactory")
	self._structureEntityFactory = registry:Get("StructureEntityFactory")
	self._enemyContext = registry:Get("EnemyContext")
	self._structureContext = registry:Get("StructureContext")
end

--[=[
	@within EndCombat
	Cancels every active executor, clears enemy action state, and stops the active combat session.
	@param userId number? -- Optional user id to stop; falls back to the first connected player.
	@return Result.Result<boolean> -- Success confirmation or a typed combat error.
]=]
function EndCombat:Execute(userId: number?): Result.Result<boolean>
	return Result.Catch(function()
		-- Default to the lone player when callers omit an explicit user id.
		local targetUserId = userId
		if targetUserId == nil then
			local players = Players:GetPlayers()
			if players[1] then
				targetUserId = players[1].UserId
			end
		end

		-- Build the cleanup payload once so each runtime cancellation gets the same service view.
		local services = {
			EnemyEntityFactory = self._enemyEntityFactory,
			StructureEntityFactory = self._structureEntityFactory,
			EnemyContext = self._enemyContext,
			StructureContext = self._structureContext,
			CurrentTime = os.clock(),
			HitboxService = self._hitboxService,
			MovementService = self._movementService,
			CombatHitResolutionService = self._combatHitResolutionService,
		}

		-- Cancel each active runtime action before clearing its stored combat state.
		for _, entity in ipairs(self._enemyEntityFactory:QueryAliveEntities()) do
			_cancelRuntimeAction(
				"Combat:EndCombat",
				self._behaviorRuntimeService,
				entity,
				_cloneActionState(self._enemyEntityFactory:GetCombatAction(entity)),
				services
			)
			self._lockOnService:DetachConstraint(entity)
			self._enemyEntityFactory:ClearTarget(entity)
			self._enemyEntityFactory:ClearAction(entity)
		end

		-- Clear structure actions separately because they use the same runtime but a different factory.
		for _, entity in ipairs(self._structureEntityFactory:QueryActiveEntities()) do
			_cancelRuntimeAction(
				"Combat:EndCombat",
				self._behaviorRuntimeService,
				entity,
				_cloneActionState(self._structureEntityFactory:GetCombatAction(entity)),
				services
			)
			self._structureEntityFactory:ClearAction(entity)
		end

		-- Sync structure visuals before the shared cleanup tears down hitboxes and combat state.
		local structureSyncServiceResult = self._structureContext:GetGameObjectSyncService()
		if structureSyncServiceResult.success then
			structureSyncServiceResult.value:SyncAll()
		end

		self._hitboxService:CleanupAll()
		self._combatHitResolutionService:CleanupAll()
		self._movementService:CleanupAll()

		if targetUserId then
			self._loopService:StopCombat(targetUserId)
		end

		return Ok(true)
	end, "Combat:EndCombat")
end

return EndCombat
