--!strict

--[=[
    @class ApplyDamageBaseCommand
    Applies damage to the active base and emits the base-destroyed event once.
    @server
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Result = require(ReplicatedStorage.Utilities.Result)
local BaseCommand = require(ServerStorage.Utilities.ContextUtilities.BaseApplication.BaseCommand)
local Errors = require(script.Parent.Parent.Parent.Errors)

local Ok = Result.Ok
local Ensure = Result.Ensure
local Try = Result.Try

local ApplyDamageBaseCommand = {}
ApplyDamageBaseCommand.__index = ApplyDamageBaseCommand
setmetatable(ApplyDamageBaseCommand, BaseCommand)

--[=[
    Create a new apply-damage command.
    @within ApplyDamageBaseCommand
    @return ApplyDamageBaseCommand -- Command instance.
]=]
function ApplyDamageBaseCommand.new()
	local self = BaseCommand.new("Base", "ApplyDamageBaseCommand")
	return setmetatable(self, ApplyDamageBaseCommand)
end

--[=[
    Bind the base entity factory and sync service dependencies.
    @within ApplyDamageBaseCommand
    @param registry any -- Registry that provides dependencies.
    @param _name string -- Module name supplied by the BaseContext framework.
]=]
function ApplyDamageBaseCommand:Init(registry: any, _name: string)
	self:_RequireDependencies(registry, {
		_baseEntityReadService = "BaseEntityReadService",
		_combatContext = "CombatContext",
	})
end

--[=[
    Apply damage, sync the new state, and emit the destroyed event if needed.
    @within ApplyDamageBaseCommand
    @param amount number -- Damage to apply to the base.
    @return Result.Result<boolean> -- Whether the base died from the hit.
]=]
function ApplyDamageBaseCommand:Execute(amount: number): Result.Result<boolean>
	return Result.Catch(function()
		Ensure(type(amount) == "number" and amount > 0, "InvalidDamageAmount", Errors.INVALID_DAMAGE_AMOUNT, {
			Amount = amount,
		})
		local baseEntity = self._baseEntityReadService:GetActiveBaseEntity()
		Ensure(baseEntity ~= nil, "BaseNotFound", Errors.BASE_NOT_FOUND)

		local previousState = self._baseEntityReadService:GetBaseState()
		Ensure(previousState ~= nil, "BaseNotFound", Errors.BASE_NOT_FOUND)

		Try(self._combatContext:RequestDamage({
			VictimEntity = baseEntity,
			VictimKind = "Base",
			Amount = amount,
			Reason = "Base",
		}))

		return Ok(previousState.Hp - amount <= 0)
	end, self:_Label())
end

function ApplyDamageBaseCommand:ResetDeathEmission()
end

return ApplyDamageBaseCommand
