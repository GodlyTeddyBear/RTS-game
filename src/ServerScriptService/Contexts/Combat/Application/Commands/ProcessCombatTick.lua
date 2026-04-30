--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Result = require(ReplicatedStorage.Utilities.Result)
local BaseCommand = require(ReplicatedStorage.Utilities.BaseApplication.BaseCommand)

local Ok = Result.Ok

local ProcessCombatTick = {}
ProcessCombatTick.__index = ProcessCombatTick
setmetatable(ProcessCombatTick, BaseCommand)

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
		local frameResult = self._behaviorRuntimeService:RunFrame({
			CurrentTime = currentTime,
			DeltaTime = dt,
			Services = self:_BuildRuntimeServices(currentTime),
		})

		self:_ResolveAdvanceSuccesses(frameResult)

		return Ok(true)
	end, self:_Label())
end

function ProcessCombatTick:_BuildRuntimeServices(currentTime: number): any
	return {
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
end

function ProcessCombatTick:_ResolveAdvanceSuccesses(frameResult: any)
	for _, entityResult in ipairs(frameResult.EntityResults) do
		if entityResult.ActorType ~= "Enemy" then
			continue
		end

		if entityResult.TickActionId ~= "Advance" or entityResult.TickStatus ~= "Success" then
			continue
		end

		local goalResult = self._handleGoalReachedCommand:Execute(entityResult.Entity)
		if not goalResult.success then
			Result.MentionError("Combat:ProcessCombatTick", "Failed goal-reached handling", {
				EnemyEntity = entityResult.Entity,
				CauseType = goalResult.type,
				CauseMessage = goalResult.message,
			}, goalResult.type)
		end
	end
end

return ProcessCombatTick
