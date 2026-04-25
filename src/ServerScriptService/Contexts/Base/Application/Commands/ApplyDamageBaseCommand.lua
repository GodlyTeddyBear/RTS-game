--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameEvents = require(ReplicatedStorage.Events.GameEvents)
local Result = require(ReplicatedStorage.Utilities.Result)
local Errors = require(script.Parent.Parent.Parent.Errors)

local Ok = Result.Ok
local Ensure = Result.Ensure

local ApplyDamageBaseCommand = {}
ApplyDamageBaseCommand.__index = ApplyDamageBaseCommand

function ApplyDamageBaseCommand.new()
	return setmetatable({}, ApplyDamageBaseCommand)
end

function ApplyDamageBaseCommand:Init(registry: any, _name: string)
	self._entityFactory = registry:Get("BaseEntityFactory")
	self._syncService = registry:Get("BaseSyncService")
	self._hasEmittedDeath = false
end

function ApplyDamageBaseCommand:Execute(amount: number): Result.Result<boolean>
	return Result.Catch(function()
		Ensure(type(amount) == "number" and amount > 0, "InvalidDamageAmount", Errors.INVALID_DAMAGE_AMOUNT, {
			Amount = amount,
		})
		Ensure(self._entityFactory:IsActive(), "BaseNotFound", Errors.BASE_NOT_FOUND)

		local previousHealth = self._entityFactory:GetHealth()
		Ensure(previousHealth ~= nil, "BaseNotFound", Errors.BASE_NOT_FOUND)

		local didDie = self._entityFactory:ApplyDamage(amount)
		self._syncService:SyncBaseState()

		if previousHealth.hp > 0 and didDie and not self._hasEmittedDeath then
			self._hasEmittedDeath = true
			GameEvents.Bus:Emit(GameEvents.Events.Base.BaseDestroyed)
		end

		return Ok(didDie)
	end, "Base:ApplyDamageBaseCommand")
end

function ApplyDamageBaseCommand:ResetDeathEmission()
	self._hasEmittedDeath = false
end

return ApplyDamageBaseCommand
