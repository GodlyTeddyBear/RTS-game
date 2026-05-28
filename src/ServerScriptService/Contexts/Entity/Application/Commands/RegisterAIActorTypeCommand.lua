--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local BaseCommand = require(ServerStorage.Utilities.ContextUtilities.BaseApplication.BaseCommand)
local Result = require(ReplicatedStorage.Utilities.Result)
local EntityOperationSupport = require(script.Parent.Parent.Support.EntityOperationSupport)

local RegisterAIActorTypeCommand = {}
RegisterAIActorTypeCommand.__index = RegisterAIActorTypeCommand
setmetatable(RegisterAIActorTypeCommand, BaseCommand)

function RegisterAIActorTypeCommand.new()
	local self = BaseCommand.new("Entity", "RegisterAIActorType")
	return setmetatable(self, RegisterAIActorTypeCommand)
end

function RegisterAIActorTypeCommand:Init(registry: any, _name: string)
	self:_RequireDependencies(registry, {
		_lifecycle = "EntityLifecycleStateMachine",
		_validationService = "EntityValidationService",
		_aiActorTypeRegistry = "EntityAIActorTypeRegistry",
		_combatAIRuntimeBridge = "EntityCombatAIRuntimeBridge",
	})
end

function RegisterAIActorTypeCommand:Execute(payload: any): Result.Result<boolean>
	return Result.Catch(function()
		local lifecycleResult = EntityOperationSupport.RequireLifecycleStates(self._validationService, "RegisterAIActorType", self._lifecycle:GetState(), {
			"ReadyForAIRegistration",
			"RegisteringAI",
		})
		if not lifecycleResult.success then
			return lifecycleResult
		end

		local adopterPayload = payload
		if type(payload) == "table" then
			adopterPayload = table.clone(payload)
			adopterPayload.Source = "Adopter"
		end

		local compiledActorTypeResult = self._validationService:ValidateAIActorTypePayload(adopterPayload)
		if not compiledActorTypeResult.success then
			return compiledActorTypeResult
		end

		local registerResult = self._aiActorTypeRegistry:RegisterActorType(compiledActorTypeResult.value)
		if not registerResult.success then
			return registerResult
		end

		local bridgeResult = self._combatAIRuntimeBridge:RegisterActorType(registerResult.value)
		if not bridgeResult.success then
			self._aiActorTypeRegistry:RemoveCompiledActorType(registerResult.value.RuntimeKind, registerResult.value.ActorType)
			return bridgeResult
		end

		if self._lifecycle:GetState() == "ReadyForAIRegistration" then
			local transitionResult = self._lifecycle:BeginAIRegistration()
			if not transitionResult.success then
				return transitionResult
			end
		end

		return Result.Ok(true)
	end, self:_Label())
end

return RegisterAIActorTypeCommand
