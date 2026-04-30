--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Result = require(ReplicatedStorage.Utilities.Result)
local BaseCommand = require(ReplicatedStorage.Utilities.BaseApplication.BaseCommand)

local Ok = Result.Ok

--[=[
	@class EndCombat
	Cancels active executors and clears active combat sessions.
	@server
]=]
local EndCombat = {}
EndCombat.__index = EndCombat
setmetatable(EndCombat, BaseCommand)

--[=[
	@within EndCombat
	Creates a new combat teardown command.
	@return EndCombat -- Command instance used to end combat sessions.
]=]
function EndCombat.new()
	local self = BaseCommand.new("Combat", "EndCombat")
	return setmetatable(self, EndCombat)
end

--[=[
	@within EndCombat
	Resolves the combat loop, behavior runtime, and enemy factory dependencies.
	@param registry any -- Registry instance supplied by the context bootstrap.
	@param _name string -- Registry key used to register the command.
]=]
function EndCombat:Init(registry: any, _name: string)
	self:_RequireDependencies(registry, {
		_loopService = "CombatLoopService",
		_behaviorRuntimeService = "CombatBehaviorRuntimeService",
		_combatHitResolutionService = "CombatHitResolutionService",
		_hitboxService = "HitboxService",
		_lockOnService = "LockOnService",
		_movementService = "MovementService",
	})
end

--[=[
	@within EndCombat
	Stores the enemy factory needed to clear combat-owned state.
	@param registry any -- Registry instance used to resolve dependencies.
	@param _name string -- Registry key used to register the command.
]=]
function EndCombat:Start(registry: any, _name: string)
	self:_RequireDependencies(registry, {
		_enemyEntityFactory = "EnemyEntityFactory",
		_structureEntityFactory = "StructureEntityFactory",
		_enemyContext = "EnemyContext",
		_structureContext = "StructureContext",
	})
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
			self._behaviorRuntimeService:CancelActorAction("Enemy", entity, {
				CurrentTime = services.CurrentTime,
				Services = services,
			})
			self._lockOnService:DetachConstraint(entity)
			self._enemyEntityFactory:ClearTarget(entity)
			self._enemyEntityFactory:ClearAction(entity)
		end

		-- Clear structure actions separately because they use the same runtime but a different factory.
		for _, entity in ipairs(self._structureEntityFactory:QueryActiveEntities()) do
			self._behaviorRuntimeService:CancelActorAction("Structure", entity, {
				CurrentTime = services.CurrentTime,
				Services = services,
			})
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
	end, self:_Label())
end

return EndCombat
