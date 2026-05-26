--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Result = require(ReplicatedStorage.Utilities.Result)

local Errors = require(script.Parent.Parent.Parent.Errors)

export type TEntityAIRegistrationRecord = {
	Entity: number,
	RuntimeKind: "Combat",
	ActorHandle: string,
	CompiledActorType: any,
	FactsResolver: any?,
	ServicesResolver: any?,
	IsCleanedUp: boolean,
}

local EntityAIEntityRegistry = {}
EntityAIEntityRegistry.__index = EntityAIEntityRegistry

function EntityAIEntityRegistry.new()
	local self = setmetatable({}, EntityAIEntityRegistry)
	self._registrationsByEntity = {}
	return self
end

function EntityAIEntityRegistry:Init(_registry: any, _name: string)
end

function EntityAIEntityRegistry:RegisterAIRegistration(
	entity: number,
	registration: TEntityAIRegistrationRecord
): Result.Result<string>
	return Result.Catch(function()
		if type(entity) ~= "number" or type(registration) ~= "table" then
			return Result.Err("InvalidAIRegistration", Errors.INVALID_AI_REGISTRATION, {
				Entity = entity,
			})
		end

		if self._registrationsByEntity[entity] ~= nil then
			return Result.Err("DuplicateAIEntityRegistration", Errors.DUPLICATE_AI_ENTITY_REGISTRATION, {
				Entity = entity,
				ActorType = registration.CompiledActorType.ActorType,
				ActorHandle = registration.ActorHandle,
			})
		end

		self._registrationsByEntity[entity] = registration
		return Result.Ok(registration.ActorHandle)
	end, "EntityAIEntityRegistry:RegisterAIRegistration")
end

function EntityAIEntityRegistry:GetAIRegistration(entity: number): TEntityAIRegistrationRecord?
	return self._registrationsByEntity[entity]
end

function EntityAIEntityRegistry:GetAIActorHandle(entity: number): string?
	local registration = self._registrationsByEntity[entity]
	return if registration ~= nil then registration.ActorHandle else nil
end

function EntityAIEntityRegistry:RemoveAIRegistration(entity: number): TEntityAIRegistrationRecord?
	local registration = self._registrationsByEntity[entity]
	self._registrationsByEntity[entity] = nil
	return registration
end

function EntityAIEntityRegistry:CollectRegisteredEntities(): { number }
	local entities = {}
	for entity in pairs(self._registrationsByEntity) do
		table.insert(entities, entity)
	end
	table.sort(entities)
	return entities
end

function EntityAIEntityRegistry:GetStatus(): any
	local registrationCount = 0
	local cleanedRegistrationCount = 0

	for _, registration in pairs(self._registrationsByEntity) do
		registrationCount += 1
		if registration.IsCleanedUp then
			cleanedRegistrationCount += 1
		end
	end

	return table.freeze({
		RegistrationCount = registrationCount,
		CleanedRegistrationCount = cleanedRegistrationCount,
	})
end

return EntityAIEntityRegistry
