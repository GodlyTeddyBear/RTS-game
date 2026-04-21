--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameEvents = require(ReplicatedStorage.Events.GameEvents)

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

function ApplyDamageEnemy.new()
	return setmetatable({}, ApplyDamageEnemy)
end

function ApplyDamageEnemy:Init(registry: any, _name: string)
	self._entityFactory = registry:Get("EnemyEntityFactory")
	self._despawnEnemyCommand = registry:Get("DespawnEnemyCommand")
end

function ApplyDamageEnemy:Execute(entity: any, amount: number): Result.Result<boolean>
	return Result.Catch(function()
		Ensure(entity ~= nil, "InvalidEntity", Errors.INVALID_ENTITY)
		Ensure(amount > 0, "InvalidDamageAmount", Errors.INVALID_DAMAGE_AMOUNT, {
			Amount = amount,
		})

		local identity = self._entityFactory:GetIdentity(entity)
		Ensure(identity ~= nil, "InvalidEntity", Errors.INVALID_ENTITY)

		local nextHp = self._entityFactory:ApplyDamage(entity, amount)
		if nextHp <= 0 then
			local deathCFrame = self._entityFactory:GetDeathCFrame(entity) or CFrame.new()
			GameEvents.Bus:Emit(GameEvents.Events.Wave.EnemyDied, identity.role, identity.waveNumber, deathCFrame)
			Try(self._despawnEnemyCommand:Execute(entity))
			return Ok(true)
		end

		return Ok(false)
	end, "Enemy:ApplyDamageEnemy")
end

return ApplyDamageEnemy
