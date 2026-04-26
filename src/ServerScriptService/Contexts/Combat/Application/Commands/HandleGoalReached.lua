--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameEvents = require(ReplicatedStorage.Events.GameEvents)
local EnemyConfig = require(ReplicatedStorage.Contexts.Enemy.Config.EnemyConfig)

local Result = require(ReplicatedStorage.Utilities.Result)
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

local function _isWithinBaseDamageRange(enemyCFrame: CFrame?, baseCFrame: CFrame?, attackRange: any): boolean
	if enemyCFrame == nil or baseCFrame == nil then
		return false
	end

	if type(attackRange) ~= "number" or attackRange <= 0 then
		return false
	end

	local offset = baseCFrame.Position - enemyCFrame.Position
	return offset:Dot(offset) <= attackRange * attackRange
end

--[=[
	@within HandleGoalReached
	Creates a new goal-resolution command.
	@return HandleGoalReached -- Command instance used to resolve goal-reaching enemies.
]=]
function HandleGoalReached.new()
	return setmetatable({}, HandleGoalReached)
end

--[=[
	@within HandleGoalReached
	Resolves the enemy and base dependencies needed for goal cleanup.
	@param registry any -- Registry instance supplied by the context bootstrap.
	@param _name string -- Registry key used to register the command.
]=]
function HandleGoalReached:Init(registry: any, _name: string)
	self.Registry = registry
end

--[=[
	@within HandleGoalReached
	Caches the enemy and commander contexts after the registry is fully initialized.
]=]
function HandleGoalReached:Start()
	self._enemyContext = self.Registry:Get("EnemyContext")
	self._entityFactory = self.Registry:Get("EnemyEntityFactory")
	self._baseContext = self.Registry:Get("BaseContext")
	self._baseEntityFactory = self.Registry:Get("BaseEntityFactory")
end

--[=[
	@within HandleGoalReached
	Marks the enemy as resolved, emits wave death events, and applies base damage.
	@param entity any -- Enemy entity id that reached the goal.
	@return Result.Result<boolean> -- Success confirmation or a typed combat error.
]=]
function HandleGoalReached:Execute(entity: any): Result.Result<boolean>
	return Result.Catch(function()
		-- Validate the enemy entity before reading its state.
		Ensure(entity ~= nil, "InvalidEnemyEntity", Errors.INVALID_ENEMY_ENTITY)

		local identity = self._entityFactory:GetIdentity(entity)
		Ensure(identity ~= nil, "InvalidEnemyEntity", Errors.INVALID_ENEMY_ENTITY)

		-- Read the enemy role so the commander damage can use the configured role tuning.
		local roleConfig = EnemyConfig.ROLES[identity.role]
		Ensure(roleConfig ~= nil, "InvalidRole", Errors.INVALID_ROLE)

		local deathCFrame = self._entityFactory:GetDeathCFrame(entity)
		Ensure(deathCFrame ~= nil, "InvalidEnemyEntity", Errors.INVALID_ENEMY_ENTITY)

		local baseCFrame = self._baseEntityFactory:GetTargetCFrame()
		Ensure(baseCFrame ~= nil, "InactiveBase", Errors.INACTIVE_BASE)

		if not _isWithinBaseDamageRange(deathCFrame, baseCFrame, roleConfig.attackRange) then
			return Ok(false)
		end

		-- Emit the death event before despawning so downstream listeners can capture the final position.
		self._entityFactory:MarkGoalReached(entity)
		GameEvents.Bus:Emit(GameEvents.Events.Wave.EnemyDied, identity.role, identity.waveNumber, deathCFrame)

		Try(self._enemyContext:DespawnEnemy(entity))

		Try(self._baseContext:ApplyDamage(roleConfig.damage))

		return Ok(true)
	end, "Combat:HandleGoalReached")
end

return HandleGoalReached
