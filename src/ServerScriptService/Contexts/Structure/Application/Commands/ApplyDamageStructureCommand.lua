--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local BaseCommand = require(ServerStorage.Utilities.ContextUtilities.BaseApplication.BaseCommand)
local Result = require(ReplicatedStorage.Utilities.Result)
local Errors = require(script.Parent.Parent.Parent.Errors)

local Ensure = Result.Ensure
local Ok = Result.Ok
local Try = Result.Try

local ApplyDamageStructureCommand = {}
ApplyDamageStructureCommand.__index = ApplyDamageStructureCommand
setmetatable(ApplyDamageStructureCommand, BaseCommand)

function ApplyDamageStructureCommand.new()
	local self = BaseCommand.new("Structure", "ApplyDamageStructure")
	return setmetatable(self, ApplyDamageStructureCommand)
end

function ApplyDamageStructureCommand:Init(registry: any, _name: string)
	self:_RequireDependency(registry, "_readService", "StructureEntityReadService")
end

function ApplyDamageStructureCommand:Start(registry: any, _name: string)
	self._combatContext = registry:Get("CombatContext")
end

function ApplyDamageStructureCommand:Execute(entity: any, amount: number): Result.Result<boolean>
	return Result.Catch(function()
		Ensure(type(entity) == "number", "EntityNotFound", Errors.ENTITY_NOT_FOUND)
		Ensure(type(amount) == "number" and amount > 0, "InvalidDamageAmount", Errors.INVALID_DAMAGE_AMOUNT, {
			Amount = amount,
			Entity = entity,
		})
		Ensure(self._readService:IsPlaced(entity), "EntityNotFound", Errors.ENTITY_NOT_FOUND, { Entity = entity })

		Try(self._combatContext:RequestDamage({
			ActionId = "ExternalDamage",
			AbilityId = "ExternalDamage",
			AttackerEntity = 0,
			VictimEntity = entity,
			VictimKind = "Structure",
			Amount = amount,
			Reason = "StructureContext:ApplyDamage",
		}))
		return Ok(true)
	end, "Structure:ApplyDamageStructureCommand")
end

return ApplyDamageStructureCommand
