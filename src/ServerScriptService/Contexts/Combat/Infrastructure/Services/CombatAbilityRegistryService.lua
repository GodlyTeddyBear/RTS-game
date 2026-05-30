--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Result = require(ReplicatedStorage.Utilities.Result)

local Errors = require(script.Parent.Parent.Parent.Errors)

local CombatAbilityRegistryService = {}
CombatAbilityRegistryService.__index = CombatAbilityRegistryService

function CombatAbilityRegistryService.new()
	local self = setmetatable({}, CombatAbilityRegistryService)
	self._abilitiesById = {}
	return self
end

function CombatAbilityRegistryService:Init(_registry: any, _name: string)
end

function CombatAbilityRegistryService:RegisterAbility(payload: any): Result.Result<boolean>
	return Result.Catch(function()
		local validationResult = self:_ValidateAbility(payload)
		if not validationResult.success then
			return validationResult
		end

		if self._abilitiesById[payload.AbilityId] ~= nil then
			return Result.Err("DuplicateCombatAbility", Errors.DUPLICATE_COMBAT_ABILITY, {
				AbilityId = payload.AbilityId,
			})
		end

		self._abilitiesById[payload.AbilityId] = table.freeze(self:_DeepClone(payload))
		return Result.Ok(true)
	end, "CombatAbilityRegistryService:RegisterAbility")
end

function CombatAbilityRegistryService:SeedAbilities(abilityMap: any): Result.Result<boolean>
	return Result.Catch(function()
		for _, payload in pairs(abilityMap) do
			local registerResult = self:RegisterAbility(payload)
			if not registerResult.success and registerResult.type ~= "DuplicateCombatAbility" then
				return registerResult
			end
		end

		return Result.Ok(true)
	end, "CombatAbilityRegistryService:SeedAbilities")
end

function CombatAbilityRegistryService:GetAbility(abilityId: string): any?
	return self._abilitiesById[abilityId]
end

function CombatAbilityRegistryService:_ValidateAbility(payload: any): Result.Result<boolean>
	if type(payload) ~= "table" or type(payload.AbilityId) ~= "string" or payload.AbilityId == "" then
		return Result.Err("InvalidCombatAbility", Errors.INVALID_COMBAT_ABILITY, {
			Reason = "MissingAbilityId",
		})
	end
	if type(payload.Mechanic) ~= "string" or payload.Mechanic == "" then
		return Result.Err("InvalidCombatAbility", Errors.INVALID_COMBAT_ABILITY, {
			AbilityId = payload.AbilityId,
			Reason = "MissingMechanic",
		})
	end
	if payload.Damage ~= nil and type(payload.Damage) ~= "number" then
		return Result.Err("InvalidCombatAbility", Errors.INVALID_COMBAT_ABILITY, {
			AbilityId = payload.AbilityId,
			Reason = "InvalidDamage",
		})
	end
	if payload.Cooldown ~= nil and type(payload.Cooldown) ~= "number" then
		return Result.Err("InvalidCombatAbility", Errors.INVALID_COMBAT_ABILITY, {
			AbilityId = payload.AbilityId,
			Reason = "InvalidCooldown",
		})
	end

	return Result.Ok(true)
end

function CombatAbilityRegistryService:_DeepClone(value: any): any
	if type(value) ~= "table" then
		return value
	end

	local clone = {}
	for key, nestedValue in pairs(value) do
		clone[key] = self:_DeepClone(nestedValue)
	end
	return clone
end

return CombatAbilityRegistryService
