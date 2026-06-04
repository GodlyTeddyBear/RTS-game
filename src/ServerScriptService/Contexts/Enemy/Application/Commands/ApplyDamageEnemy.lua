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
	self:_RequireDependency(registry, "_enemyEntityReadService", "EnemyEntityReadService")
end

function ApplyDamageEnemy:Start(registry: any, _name: string)
	self._combatContext = registry:Get("CombatContext")
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

		Try(self._combatContext:RequestDamage({
			ActionId = "ExternalDamage",
			AbilityId = "ExternalDamage",
			AttackerEntity = 0,
			VictimEntity = entity,
			VictimKind = "Enemy",
			Amount = amount,
			Reason = "EnemyContext:ApplyDamage",
		}))
		return Ok(true)
	end, "Enemy:ApplyDamageEnemy")
end

return ApplyDamageEnemy
