--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Result = require(ReplicatedStorage.Utilities.Result)
local Errors = require(script.Parent.Parent.Parent.Errors)

local Ok = Result.Ok
local Ensure = Result.Ensure
local Try = Result.Try

--[=[
	@class ApplyDamageStructureCommand
	Applies damage to a structure and disables it when health reaches zero.
	@server
]=]
local ApplyDamageStructureCommand = {}
ApplyDamageStructureCommand.__index = ApplyDamageStructureCommand

function ApplyDamageStructureCommand.new()
	return setmetatable({}, ApplyDamageStructureCommand)
end

function ApplyDamageStructureCommand:Init(registry: any, _name: string)
	self._factory = registry:Get("StructureEntityFactory")
end

function ApplyDamageStructureCommand:Start(registry: any, _name: string)
	self._placementContext = registry:Get("PlacementContext")
end

function ApplyDamageStructureCommand:Execute(entity: any, amount: number): Result.Result<boolean>
	return Result.Catch(function()
		Ensure(type(entity) == "number", "EntityNotFound", Errors.ENTITY_NOT_FOUND)
		Ensure(type(amount) == "number" and amount > 0, "InvalidDamageAmount", Errors.INVALID_DAMAGE_AMOUNT, {
			Amount = amount,
			Entity = entity,
		})
		Ensure(self._factory:IsActive(entity), "EntityNotFound", Errors.ENTITY_NOT_FOUND, {
			Entity = entity,
		})

		local instanceRef = self._factory:GetInstanceRef(entity)
		Ensure(instanceRef ~= nil, "EntityNotFound", Errors.ENTITY_NOT_FOUND, {
			Entity = entity,
		})

		local health = self._factory:GetHealth(entity)
		Ensure(health ~= nil, "EntityNotFound", Errors.ENTITY_NOT_FOUND, {
			Entity = entity,
		})

		local didDie = self._factory:ApplyDamage(entity, amount)
		if didDie then
			self._factory:ClearModelRef(entity)
			self._factory:DeleteEntity(entity)
			Try(self._placementContext:DestroyStructureInstance(instanceRef.InstanceId))
			return Ok(true)
		end

		return Ok(false)
	end, "Structure:ApplyDamageStructureCommand")
end

return ApplyDamageStructureCommand
