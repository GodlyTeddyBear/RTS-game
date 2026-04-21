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

function HandleGoalReached.new()
	return setmetatable({}, HandleGoalReached)
end

function HandleGoalReached:Init(registry: any, _name: string)
	self.Registry = registry
	self._movementService = registry:Get("CombatMovementService")
end

function HandleGoalReached:Start()
	self._enemyContext = self.Registry:Get("EnemyContext")
	self._entityFactory = self.Registry:Get("EnemyEntityFactory")
	self._commanderContext = self.Registry:Get("CommanderContext")
end

function HandleGoalReached:Execute(entity: any): Result.Result<boolean>
	return Result.Catch(function()
		Ensure(entity ~= nil, "InvalidEnemyEntity", Errors.INVALID_ENEMY_ENTITY)

		local identity = self._entityFactory:GetIdentity(entity)
		Ensure(identity ~= nil, "InvalidEnemyEntity", Errors.INVALID_ENEMY_ENTITY)

		local roleConfig = EnemyConfig.ROLES[identity.role]
		Ensure(roleConfig ~= nil, "InvalidRole", Errors.INVALID_ROLE)

		local deathCFrame = self._entityFactory:GetDeathCFrame(entity) or CFrame.new()
		self._movementService:Cancel(entity)
		self._entityFactory:MarkGoalReached(entity)
		GameEvents.Bus:Emit(GameEvents.Events.Wave.EnemyDied, identity.role, identity.waveNumber, deathCFrame)

		Try(self._enemyContext:DespawnEnemy(entity))

		local players = Players:GetPlayers()
		local primaryPlayer = players[1]
		if primaryPlayer then
			Try(self._commanderContext:ApplyDamage(primaryPlayer, roleConfig.damage))
		end

		return Ok(true)
	end, "Combat:HandleGoalReached")
end

return HandleGoalReached
