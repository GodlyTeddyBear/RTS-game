--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BaseCommand = require(ReplicatedStorage.Utilities.BaseApplication.BaseCommand)
local Result = require(ReplicatedStorage.Utilities.Result)
local EnemyConfig = require(ReplicatedStorage.Contexts.Enemy.Config.EnemyConfig)
local Errors = require(script.Parent.Parent.Parent.Errors)

local Ok = Result.Ok
local Ensure = Result.Ensure
local Try = Result.Try

--[=[
	@class HandleGoalReached
	Handles enemy goal contact by notifying wave logic, damaging the commander, and despawning the enemy.
	@server
]=]
local HandleGoalReached = {}
HandleGoalReached.__index = HandleGoalReached
setmetatable(HandleGoalReached, BaseCommand)

function HandleGoalReached.new()
	local self = BaseCommand.new("Enemy", "HandleGoalReached")
	return setmetatable(self, HandleGoalReached)
end

function HandleGoalReached:Init(registry: any, _name: string)
	self:_RequireDependencies(registry, {
		_entityFactory = "EnemyEntityFactory",
		_despawnEnemyCommand = "DespawnEnemyCommand",
	})
end

function HandleGoalReached:Execute(entity: any, primaryPlayer: Player?, commanderContext: any): Result.Result<boolean>
	return Result.Catch(function()
		Ensure(entity ~= nil, "InvalidEntity", Errors.INVALID_ENTITY)

		local identity = self._entityFactory:GetIdentity(entity)
		Ensure(identity ~= nil, "InvalidEntity", Errors.INVALID_ENTITY)

		local roleConfig = EnemyConfig.Roles[identity.Role]
		Ensure(roleConfig ~= nil, "InvalidRole", Errors.INVALID_ROLE)

		self._entityFactory:MarkGoalReached(entity)
		local deathCFrame = self._entityFactory:GetDeathCFrame(entity) or CFrame.new()
		self:_EmitGameEvent("Wave", "EnemyDied", identity.Role, identity.WaveNumber, deathCFrame)

		Try(self._despawnEnemyCommand:Execute(entity))

		if primaryPlayer and commanderContext then
			local damageResult = commanderContext:ApplyDamage(primaryPlayer, roleConfig.Damage)
			if not damageResult.success then
				Result.MentionError("Enemy:HandleGoalReached", "Failed to apply commander damage", {
					EnemyId = identity.EnemyId,
					Role = identity.Role,
					WaveNumber = identity.WaveNumber,
					PlayerUserId = primaryPlayer.UserId,
				}, damageResult.type)
			end
		end

		return Ok(true)
	end, "Enemy:HandleGoalReached")
end

return HandleGoalReached
