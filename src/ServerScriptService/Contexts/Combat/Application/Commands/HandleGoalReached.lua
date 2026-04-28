--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local EnemyConfig = require(ReplicatedStorage.Contexts.Enemy.Config.EnemyConfig)

local Result = require(ReplicatedStorage.Utilities.Result)
local BaseCommand = require(ReplicatedStorage.Utilities.BaseApplication.BaseCommand)
local Errors = require(script.Parent.Parent.Parent.Errors)

local Ok = Result.Ok
local Ensure = Result.Ensure
local Try = Result.Try

--[=[
	@class HandleGoalReached
	Resolves an enemy reaching the lane goal.
	@server
]=]
local HandleGoalReached = {}
HandleGoalReached.__index = HandleGoalReached
setmetatable(HandleGoalReached, BaseCommand)

--[=[
	@within HandleGoalReached
	Creates a new goal-resolution command.
	@return HandleGoalReached -- Command instance used to resolve goal-reaching enemies.
]=]
function HandleGoalReached.new()
	local self = BaseCommand.new("Combat", "HandleGoalReached")
	return setmetatable(self, HandleGoalReached)
end

--[=[
	@within HandleGoalReached
	Resolves the enemy and base dependencies needed for goal cleanup.
	@param registry any -- Registry instance supplied by the context bootstrap.
	@param _name string -- Registry key used to register the command.
]=]
function HandleGoalReached:Init(registry: any, _name: string)
	self:_RequireDependency(registry, "_combatPerceptionService", "CombatPerceptionService")
end

--[=[
	@within HandleGoalReached
	Caches the enemy and commander contexts after the registry is fully initialized.
]=]
function HandleGoalReached:Start(registry: any, _name: string)
	self:_RequireDependencies(registry, {
		_enemyContext = "EnemyContext",
		_entityFactory = "EnemyEntityFactory",
		_baseContext = "BaseContext",
		_baseEntityFactory = "BaseEntityFactory",
	})
end

--[=[
	@within HandleGoalReached
	Marks the enemy as resolved, emits wave death events, despawns it, and applies base damage when in range.
	@param entity any -- Enemy entity id that reached the goal.
	@return Result.Result<boolean> -- Success confirmation or a typed combat error.
]=]
function HandleGoalReached:Execute(entity: any): Result.Result<boolean>
	return Result.Catch(function()
		-- Validate the enemy entity before reading its state.
		Ensure(entity ~= nil, "InvalidEnemyEntity", Errors.INVALID_ENEMY_ENTITY)

		-- Resolve the enemy identity and role data needed to compute goal damage.
		local identity = self._entityFactory:GetIdentity(entity)
		Ensure(identity ~= nil, "InvalidEnemyEntity", Errors.INVALID_ENEMY_ENTITY)

		local roleConfig = EnemyConfig.Roles[identity.Role]
		Ensure(roleConfig ~= nil, "InvalidRole", Errors.INVALID_ROLE)

		-- Confirm the death position and base state before applying any damage.
		local deathCFrame = self._entityFactory:GetDeathCFrame(entity)
		Ensure(deathCFrame ~= nil, "InvalidEnemyEntity", Errors.INVALID_ENEMY_ENTITY)
		Ensure(self._baseEntityFactory:IsActive(), "InactiveBase", Errors.INACTIVE_BASE)

		-- Skip damage if the death point is outside the base's attack range.
		if not self._combatPerceptionService:IsTargetInRange(deathCFrame.Position, roleConfig.AttackRange, "Base", nil) then
			return Ok(false)
		end

		-- Mark the enemy resolved, emit the wave event, and apply the resulting base damage.
		self._entityFactory:MarkGoalReached(entity)
		self:_EmitGameEvent("Wave", "EnemyDied", identity.Role, identity.WaveNumber, deathCFrame)

		Try(self._enemyContext:DespawnEnemy(entity))
		Try(self._baseContext:ApplyDamage(roleConfig.Damage))

		return Ok(true)
	end, self:_Label())
end

return HandleGoalReached
