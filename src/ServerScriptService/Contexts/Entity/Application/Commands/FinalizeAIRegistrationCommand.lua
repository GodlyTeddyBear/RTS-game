--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local BaseCommand = require(ServerStorage.Utilities.ContextUtilities.BaseApplication.BaseCommand)
local Result = require(ReplicatedStorage.Utilities.Result)
local EntityProofRuntimeConfig = require(script.Parent.Parent.Parent.Config.EntityProofRuntimeConfig)

local FinalizeAIRegistrationCommand = {}
FinalizeAIRegistrationCommand.__index = FinalizeAIRegistrationCommand
setmetatable(FinalizeAIRegistrationCommand, BaseCommand)

function FinalizeAIRegistrationCommand.new()
	local self = BaseCommand.new("Entity", "FinalizeAIRegistration")
	return setmetatable(self, FinalizeAIRegistrationCommand)
end

function FinalizeAIRegistrationCommand:Init(registry: any, _name: string)
	self:_RequireDependencies(registry, {
		_lifecycle = "EntityLifecycleStateMachine",
		_validationService = "EntityValidationService",
		_aiActorTypeRegistry = "EntityAIActorTypeRegistry",
		_combatAIRuntimeBridge = "EntityCombatAIRuntimeBridge",
		_lifecyclePolicy = "EntityLifecyclePolicy",
	})
end

function FinalizeAIRegistrationCommand:Execute(): Result.Result<boolean>
	return Result.Catch(function()
		local currentState = self._lifecycle:GetState()
		if currentState ~= "ReadyForAIRegistration" and currentState ~= "RegisteringAI" then
			return Result.Ok(true)
		end

		local proofAIResult = self:_EnsureBuiltInOperationalProofActorType()
		if not proofAIResult.success then
			return proofAIResult
		end

		local finalizeAIResult = self._aiActorTypeRegistry:CloseRegistration()
		if not finalizeAIResult.success then
			return finalizeAIResult
		end

		local aiReadyResult = self._lifecyclePolicy:ValidateAIReady(self._aiActorTypeRegistry, self._combatAIRuntimeBridge)
		if aiReadyResult ~= nil then
			return aiReadyResult
		end

		return self._lifecycle:StartRunning()
	end, self:_Label())
end

function FinalizeAIRegistrationCommand:_EnsureBuiltInOperationalProofActorType(): Result.Result<boolean>
	if self._aiActorTypeRegistry:GetCompiledActorType("Combat", EntityProofRuntimeConfig.ActorType) ~= nil then
		return Result.Ok(true)
	end

	local payload = {
		RuntimeKind = "Combat",
		ActorType = EntityProofRuntimeConfig.ActorType,
		Source = "Proof",
		Conditions = {},
		Commands = EntityProofRuntimeConfig.Commands,
		Executors = EntityProofRuntimeConfig.Executors,
		ResolveProfile = function(_entityContext: any, _entity: number)
			return {
				BehaviorDefinition = EntityProofRuntimeConfig.BehaviorDefinition,
				TickInterval = 0.1,
			}
		end,
		BuildActorHandle = function(_entityContext: any, entity: number)
			return string.format("%s:%d", EntityProofRuntimeConfig.ActorType, entity)
		end,
		IsEntityActive = function(entityContext: any, entity: number)
			local hasResult = entityContext:Has(entity, "ActiveTag")
			return hasResult.success and hasResult.value == true
		end,
		GetActorLabel = function(_entityContext: any, entity: number)
			return string.format("%s#%d", EntityProofRuntimeConfig.ActorType, entity)
		end,
		DependencyContract = {
			DependencyMode = "EntityContextOnly",
			AllowsRuntimeServices = true,
			DeclaredDependencies = { "EntityContext", "RuntimeServices" },
		},
	}

	local compiledResult = self._validationService:ValidateAIActorTypePayload(payload)
	if not compiledResult.success then
		return compiledResult
	end

	local registerResult = self._aiActorTypeRegistry:RegisterActorType(compiledResult.value)
	if not registerResult.success then
		return registerResult
	end

	local bridgeResult = self._combatAIRuntimeBridge:RegisterActorType(registerResult.value)
	if not bridgeResult.success then
		self._aiActorTypeRegistry:RemoveCompiledActorType(registerResult.value.RuntimeKind, registerResult.value.ActorType)
		return bridgeResult
	end

	if self._lifecycle:GetState() == "ReadyForAIRegistration" then
		return self._lifecycle:BeginAIRegistration()
	end

	return Result.Ok(true)
end

return FinalizeAIRegistrationCommand
