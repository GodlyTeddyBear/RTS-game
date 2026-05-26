--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local BaseCommand = require(ServerStorage.Utilities.ContextUtilities.BaseApplication.BaseCommand)
local Result = require(ReplicatedStorage.Utilities.Result)
local EntityOperationSupport = require(script.Parent.Parent.Support.EntityOperationSupport)
local Errors = require(script.Parent.Parent.Parent.Errors)

local RegisterAIEntityCommand = {}
RegisterAIEntityCommand.__index = RegisterAIEntityCommand
setmetatable(RegisterAIEntityCommand, BaseCommand)

function RegisterAIEntityCommand.new()
	local self = BaseCommand.new("Entity", "RegisterAIEntity")
	return setmetatable(self, RegisterAIEntityCommand)
end

function RegisterAIEntityCommand:Init(registry: any, _name: string)
	self:_RequireDependencies(registry, {
		_lifecycle = "EntityLifecycleStateMachine",
		_validationService = "EntityValidationService",
		_entityFactory = "EntityEntityFactory",
		_aiActorTypeRegistry = "EntityAIActorTypeRegistry",
		_aiEntityRegistry = "EntityAIEntityRegistry",
		_combatAIRuntimeBridge = "EntityCombatAIRuntimeBridge",
		_aiCallbackAdapterService = "EntityAICallbackAdapterService",
		_entityContext = "EntityContextService",
	})
end

function RegisterAIEntityCommand:Execute(entity: number, actorType: string): Result.Result<string>
	return Result.Catch(function()
		local lifecycleResult = EntityOperationSupport.RequireLifecycleStates(self._validationService, "RegisterAIEntity", self._lifecycle:GetState(), {
			"RegisteringAI",
			"Running",
		})
		if not lifecycleResult.success then
			return lifecycleResult
		end

		local compiledActorType = self._aiActorTypeRegistry:GetCompiledActorType("Combat", actorType)
		if compiledActorType == nil then
			return Result.Err("UnknownAIActorType", Errors.UNKNOWN_AI_ACTOR_TYPE, {
				Entity = entity,
				ActorType = actorType,
				RuntimeKind = "Combat",
			})
		end

		if not self._entityFactory:Exists(entity) then
			return Result.Err("UnknownEntity", Errors.UNKNOWN_ENTITY, {
				Entity = entity,
			})
		end

		local registrationResult = self._combatAIRuntimeBridge:RegisterAIEntity(
			self._entityContext,
			entity,
			compiledActorType,
			self._aiCallbackAdapterService
		)
		if not registrationResult.success then
			return registrationResult
		end

		local bridgeRegistration = registrationResult.value.Registration
		local profile = registrationResult.value.Profile
		local writeRuntimeResult = self._aiCallbackAdapterService:WriteAIRegistrationRuntimeState(
			entity,
			compiledActorType,
			profile,
			bridgeRegistration.ActorHandle
		)
		if not writeRuntimeResult.success then
			self._combatAIRuntimeBridge:UnregisterAIEntity(bridgeRegistration.ActorHandle)
			self._aiCallbackAdapterService:CleanupAIRegistration(bridgeRegistration, false)
			return writeRuntimeResult
		end

		local actionStateResult = self._combatAIRuntimeBridge:GetAIActionState(bridgeRegistration.ActorHandle)
		local writeActionStateResult = if actionStateResult.success and actionStateResult.value ~= nil
			then self._aiCallbackAdapterService:WriteAIActionStateFromCombatState(entity, actionStateResult.value, os.clock())
			else self._aiCallbackAdapterService:WriteDefaultAIActionState(entity)
		if not writeActionStateResult.success then
			self._aiCallbackAdapterService:ClearAIRegistrationRuntimeState(entity)
			self._combatAIRuntimeBridge:UnregisterAIEntity(bridgeRegistration.ActorHandle)
			self._aiCallbackAdapterService:CleanupAIRegistration(bridgeRegistration, false)
			return writeActionStateResult
		end

		local storeResult = self._aiEntityRegistry:RegisterAIRegistration(entity, bridgeRegistration)
		if not storeResult.success then
			self._aiCallbackAdapterService:ClearAIRegistrationRuntimeState(entity)
			self._combatAIRuntimeBridge:UnregisterAIEntity(bridgeRegistration.ActorHandle)
			self._aiCallbackAdapterService:CleanupAIRegistration(bridgeRegistration, false)
			return storeResult
		end

		return storeResult
	end, self:_Label())
end

return RegisterAIEntityCommand