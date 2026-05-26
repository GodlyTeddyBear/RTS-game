--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Result = require(ReplicatedStorage.Utilities.Result)

local Errors = require(script.Parent.Parent.Parent.Errors)

local EntityCombatAIRuntimeBridge = {}
EntityCombatAIRuntimeBridge.__index = EntityCombatAIRuntimeBridge

local function _CleanupResolvers(entity: number, factsResolver: any?, servicesResolver: any?)
	if type(servicesResolver) == "table" and type(servicesResolver.Cleanup) == "function" then
		pcall(servicesResolver.Cleanup, servicesResolver, entity)
	end

	if type(factsResolver) == "table" and type(factsResolver.Cleanup) == "function" then
		pcall(factsResolver.Cleanup, factsResolver, entity)
	end
end

function EntityCombatAIRuntimeBridge.new()
	local self = setmetatable({}, EntityCombatAIRuntimeBridge)
	self._combatContext = nil
	return self
end

function EntityCombatAIRuntimeBridge:Init(_registry: any, _name: string)
end

function EntityCombatAIRuntimeBridge:Start(registry: any, _name: string)
	self._combatContext = registry:Get("CombatContext")
end

function EntityCombatAIRuntimeBridge:ValidateReady(): Result.Result<boolean>
	if self._combatContext == nil then
		return Result.Err("AIRuntimeBridgeUnavailable", Errors.AI_RUNTIME_BRIDGE_UNAVAILABLE, {
			RuntimeKind = "Combat",
		})
	end

	return Result.Ok(true)
end

function EntityCombatAIRuntimeBridge:RegisterActorType(compiledActorType: any): Result.Result<boolean>
	return Result.Catch(function()
		local readyResult = self:ValidateReady()
		if not readyResult.success then
			return readyResult
		end

		return self._combatContext:RegisterActorType({
			ActorType = compiledActorType.ActorType,
			Conditions = compiledActorType.Conditions,
			Commands = compiledActorType.Commands,
			Executors = compiledActorType.Executors,
			SemanticRequirements = compiledActorType.SemanticRequirements,
			RuntimeBinding = compiledActorType.RuntimeBinding,
			RuntimeOwner = compiledActorType.RuntimeOwner,
		})
	end, "EntityCombatAIRuntimeBridge:RegisterActorType")
end

function EntityCombatAIRuntimeBridge:RegisterAIEntity(
	entityContext: any,
	entity: number,
	compiledActorType: any,
	aiCallbackAdapterService: any?
): Result.Result<any>
	return Result.Catch(function()
		local readyResult = self:ValidateReady()
		if not readyResult.success then
			return readyResult
		end

		local profile = compiledActorType.ResolveProfile(entityContext, entity)
		if
			type(profile) ~= "table"
			or profile.BehaviorDefinition == nil
			or type(profile.TickInterval) ~= "number"
			or profile.TickInterval <= 0
		then
			return Result.Err("InvalidAIProfile", Errors.INVALID_AI_PROFILE, {
				Entity = entity,
				ActorType = compiledActorType.ActorType,
				RuntimeKind = compiledActorType.RuntimeKind,
			})
		end

		local actorHandle = compiledActorType.BuildActorHandle(entityContext, entity)
		if type(actorHandle) ~= "string" or actorHandle == "" then
			return Result.Err("InvalidAIRegistration", Errors.INVALID_AI_REGISTRATION, {
				Entity = entity,
				ActorType = compiledActorType.ActorType,
				RuntimeKind = compiledActorType.RuntimeKind,
				Reason = "InvalidActorHandle",
			})
		end

		local runtimeServicesResult = self._combatContext:GetCombatRuntimeServices()
		if not runtimeServicesResult.success then
			return runtimeServicesResult
		end

		local factsResolver = nil
		if type(compiledActorType.CreateFactsResolver) == "function" then
			local didCreateFacts, createdFactsResolver = pcall(compiledActorType.CreateFactsResolver, entityContext)
			if not didCreateFacts then
				return Result.Err("InvalidAIRegistration", Errors.INVALID_AI_REGISTRATION, {
					Entity = entity,
					ActorType = compiledActorType.ActorType,
					RuntimeKind = compiledActorType.RuntimeKind,
					Reason = "CreateFactsResolverFailed",
					CauseMessage = createdFactsResolver,
				})
			end
			factsResolver = createdFactsResolver
		end

		local servicesResolver = nil
		if type(compiledActorType.CreateServicesResolver) == "function" then
			local didCreateServices, createdServicesResolver =
				pcall(compiledActorType.CreateServicesResolver, entityContext, runtimeServicesResult.value)
			if not didCreateServices then
				_CleanupResolvers(entity, factsResolver, nil)
				return Result.Err("InvalidAIRegistration", Errors.INVALID_AI_REGISTRATION, {
					Entity = entity,
					ActorType = compiledActorType.ActorType,
					RuntimeKind = compiledActorType.RuntimeKind,
					Reason = "CreateServicesResolverFailed",
					CauseMessage = createdServicesResolver,
				})
			end
			servicesResolver = createdServicesResolver
		end

		local registration = {
			Entity = entity,
			RuntimeKind = "Combat",
			ActorHandle = actorHandle,
			CompiledActorType = compiledActorType,
			FactsResolver = factsResolver,
			ServicesResolver = servicesResolver,
			IsCleanedUp = false,
		}

		if aiCallbackAdapterService == nil then
			_CleanupResolvers(entity, factsResolver, servicesResolver)
			return Result.Err("InvalidAIRegistration", Errors.INVALID_AI_REGISTRATION, {
				Entity = entity,
				ActorType = compiledActorType.ActorType,
				RuntimeKind = compiledActorType.RuntimeKind,
				Reason = "MissingCallbackAdapterService",
			})
		end

		local registerResult = self._combatContext:RegisterCombatActor({
			ActorType = compiledActorType.ActorType,
			ActorHandle = actorHandle,
			BehaviorDefinition = profile.BehaviorDefinition,
			TickInterval = profile.TickInterval,
			Adapter = aiCallbackAdapterService:BuildAdapter(entityContext, registration),
		})
		if not registerResult.success then
			_CleanupResolvers(entity, factsResolver, servicesResolver)
			return registerResult
		end

		return Result.Ok({
			Registration = registration,
			Profile = {
				BehaviorDefinition = profile.BehaviorDefinition,
				TickInterval = profile.TickInterval,
			},
		})
	end, "EntityCombatAIRuntimeBridge:RegisterAIEntity")
end

function EntityCombatAIRuntimeBridge:UnregisterAIEntity(actorHandle: string): Result.Result<boolean>
	return Result.Catch(function()
		local readyResult = self:ValidateReady()
		if not readyResult.success then
			return readyResult
		end

		return self._combatContext:UnregisterCombatActor(actorHandle)
	end, "EntityCombatAIRuntimeBridge:UnregisterAIEntity")
end

function EntityCombatAIRuntimeBridge:GetAIActionState(actorHandle: string): Result.Result<any?>
	return Result.Catch(function()
		local readyResult = self:ValidateReady()
		if not readyResult.success then
			return readyResult
		end

		return self._combatContext:GetCombatActorActionState(actorHandle)
	end, "EntityCombatAIRuntimeBridge:GetAIActionState")
end

function EntityCombatAIRuntimeBridge:GetStatus(): any
	return table.freeze({
		RuntimeKind = "Combat",
		Ready = self._combatContext ~= nil,
	})
end

return EntityCombatAIRuntimeBridge
