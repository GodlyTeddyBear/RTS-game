--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local BaseCommand = require(ServerStorage.Utilities.ContextUtilities.BaseApplication.BaseCommand)
local Result = require(ReplicatedStorage.Utilities.Result)
local EntityOperationSupport = require(script.Parent.Parent.Support.EntityOperationSupport)

local UnregisterAIEntityCommand = {}
UnregisterAIEntityCommand.__index = UnregisterAIEntityCommand
setmetatable(UnregisterAIEntityCommand, BaseCommand)

function UnregisterAIEntityCommand.new()
	local self = BaseCommand.new("Entity", "UnregisterAIEntity")
	return setmetatable(self, UnregisterAIEntityCommand)
end

function UnregisterAIEntityCommand:Init(registry: any, _name: string)
	self:_RequireDependencies(registry, {
		_lifecycle = "EntityLifecycleStateMachine",
		_validationService = "EntityValidationService",
		_aiEntityRegistry = "EntityAIEntityRegistry",
		_combatAIRuntimeBridge = "EntityCombatAIRuntimeBridge",
		_aiCallbackAdapterService = "EntityAICallbackAdapterService",
	})
end

function UnregisterAIEntityCommand:Execute(entity: number): Result.Result<boolean>
	return Result.Catch(function()
		local lifecycleResult = EntityOperationSupport.RequireLifecycleStates(self._validationService, "UnregisterAIEntity", self._lifecycle:GetState(), {
			"RegisteringAI",
			"Running",
			"ShuttingDown",
		})
		if not lifecycleResult.success then
			return lifecycleResult
		end

		local registration = self._aiEntityRegistry:GetAIRegistration(entity)
		local actorHandleResult = self._aiCallbackAdapterService:ReadAIActorHandle(entity)
		local actorHandle = if actorHandleResult.success then actorHandleResult.value else nil
		if registration == nil and actorHandle == nil then
			return Result.Ok(false)
		end

		local unregisterResult = Result.Ok(false)
		if actorHandle ~= nil then
			unregisterResult = self._combatAIRuntimeBridge:UnregisterAIEntity(actorHandle)
		end

		local clearResult = self._aiCallbackAdapterService:ClearAIRegistrationRuntimeState(entity)
		if registration ~= nil then
			self._aiCallbackAdapterService:CleanupAIRegistration(registration, true)
		end

		if not clearResult.success then
			return clearResult
		end
		if not unregisterResult.success then
			return unregisterResult
		end

		return Result.Ok(true)
	end, self:_Label())
end

return UnregisterAIEntityCommand