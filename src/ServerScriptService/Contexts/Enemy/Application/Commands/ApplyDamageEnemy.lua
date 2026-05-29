--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local BaseCommand = require(ServerStorage.Utilities.ContextUtilities.BaseApplication.BaseCommand)
local Result = require(ReplicatedStorage.Utilities.Result)
local Errors = require(script.Parent.Parent.Parent.Errors)

local Ok = Result.Ok
local Ensure = Result.Ensure
local Try = Result.Try

--[=[
	@class ApplyDamageEnemy
	Applies damage to an enemy and despawns it if health reaches zero.
	@server
]=]
local ApplyDamageEnemy = {}
ApplyDamageEnemy.__index = ApplyDamageEnemy
setmetatable(ApplyDamageEnemy, BaseCommand)

function ApplyDamageEnemy.new()
	local self = BaseCommand.new("Enemy", "ApplyDamageEnemy")
	return setmetatable(self, ApplyDamageEnemy)
end

function ApplyDamageEnemy:Init(registry: any, _name: string)
	self:_RequireDependencies(registry, {
		_entityContext = "EntityContext",
		_enemyEntityReadService = "EnemyEntityReadService",
		_despawnEnemyCommand = "DespawnEnemyCommand",
	})
end

function ApplyDamageEnemy:Execute(entity: any, amount: number): Result.Result<boolean>
	return Result.Catch(function()
		Ensure(entity ~= nil, "InvalidEntity", Errors.INVALID_ENTITY)
		Ensure(type(amount) == "number" and amount > 0, "InvalidDamageAmount", Errors.INVALID_DAMAGE_AMOUNT, {
			Amount = amount,
		})

		local identity = self._enemyEntityReadService:GetIdentity(entity)
		Ensure(identity ~= nil, "InvalidEntity", Errors.INVALID_ENTITY)
		Ensure(self._enemyEntityReadService:IsAlive(entity), "InvalidEntity", Errors.INVALID_ENTITY)

		local health = self._enemyEntityReadService:GetHealth(entity)
		Ensure(health ~= nil, "InvalidEntity", Errors.INVALID_ENTITY)

		local nextHp = math.max(0, health.Current - amount)
		Try(self._entityContext:Set(entity, "Health", {
			Current = nextHp,
			Max = health.Max,
		}, "Entity"))

		local didDie = nextHp <= 0
		if didDie then
			local deathCFrame = self._enemyEntityReadService:GetEntityCFrame(entity) or CFrame.new()
			self:_EmitGameEvent("Wave", "EnemyDied", identity.Role, identity.WaveNumber, deathCFrame)
			Try(self._despawnEnemyCommand:Execute(entity))
			return Ok(true)
		end

		return Ok(false)
	end, "Enemy:ApplyDamageEnemy")
end

return ApplyDamageEnemy
