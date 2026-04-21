--!strict

local Players = game:GetService("Players")
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

-- Creates a new goal-resolution command.
function HandleGoalReached.new()
	return setmetatable({}, HandleGoalReached)
end

-- Resolves the enemy and commander dependencies needed for goal cleanup.
function HandleGoalReached:Init(registry: any, _name: string)
	self.Registry = registry
end

-- Caches the enemy and commander contexts after the registry is fully initialized.
function HandleGoalReached:Start()
	self._enemyContext = self.Registry:Get("EnemyContext")
	self._entityFactory = self.Registry:Get("EnemyEntityFactory")
	self._commanderContext = self.Registry:Get("CommanderContext")
end

-- Marks the enemy as resolved, emits wave death events, and applies commander damage.
function HandleGoalReached:Execute(entity: any): Result.Result<boolean>
	return Result.Catch(function()
		-- Validate the enemy entity before reading its state.
		Ensure(entity ~= nil, "InvalidEnemyEntity", Errors.INVALID_ENEMY_ENTITY)

		local identity = self._entityFactory:GetIdentity(entity)
		Ensure(identity ~= nil, "InvalidEnemyEntity", Errors.INVALID_ENEMY_ENTITY)

		-- Read the enemy role so the commander damage can use the configured role tuning.
		local roleConfig = EnemyConfig.ROLES[identity.role]
		Ensure(roleConfig ~= nil, "InvalidRole", Errors.INVALID_ROLE)

		-- Emit the death event before despawning so downstream listeners can capture the final position.
		local deathCFrame = self._entityFactory:GetDeathCFrame(entity) or CFrame.new()
		self._entityFactory:MarkGoalReached(entity)
		GameEvents.Bus:Emit(GameEvents.Events.Wave.EnemyDied, identity.role, identity.waveNumber, deathCFrame)

		Try(self._enemyContext:DespawnEnemy(entity))

		-- Damage the active commander if one exists in the current session.
		local players = Players:GetPlayers()
		local primaryPlayer = players[1]
		if primaryPlayer then
			Try(self._commanderContext:ApplyDamage(primaryPlayer, roleConfig.damage))
		end

		return Ok(true)
	end, "Combat:HandleGoalReached")
end

return HandleGoalReached
