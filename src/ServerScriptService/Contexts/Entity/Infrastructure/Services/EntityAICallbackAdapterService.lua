--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Result = require(ReplicatedStorage.Utilities.Result)

local EntityAICallbackAdapterService = {}
EntityAICallbackAdapterService.__index = EntityAICallbackAdapterService

local function _BuildDefaultActionState(timestamp: number): any
	return {
		Status = "Idle",
		ActionName = nil,
		StartedAt = nil,
		UpdatedAt = timestamp,
		ErrorCode = nil,
	}
end

local function _MapCombatActionState(combatActionState: any, timestamp: number): any
	if type(combatActionState) ~= "table" then
		return _BuildDefaultActionState(timestamp)
	end

	return {
		Status = combatActionState.ActionState or "Idle",
		ActionName = combatActionState.CurrentActionId or combatActionState.PendingActionId,
		StartedAt = combatActionState.StartedAt,
		UpdatedAt = timestamp,
		ErrorCode = nil,
	}
end

function EntityAICallbackAdapterService.new()
	return setmetatable({}, EntityAICallbackAdapterService)
end

function EntityAICallbackAdapterService:Init(registry: any, _name: string)
	self._entityFactory = registry:Get("EntityEntityFactory")
	self._aiEntityRegistry = registry:Get("EntityAIEntityRegistry")
end

function EntityAICallbackAdapterService:BuildAdapter(entityContext: any, registration: any): any
	return {
		IsActive = function(): boolean
			return self:_IsAIRegistrationActive(entityContext, registration)
		end,
		GetActorLabel = function(): string?
			return self:_GetAIRegistrationActorLabel(entityContext, registration)
		end,
		BuildFacts = function(currentTime: number): { [string]: any }
			return self:_BuildAIRegistrationFacts(registration, currentTime)
		end,
		BuildServices = function(currentTime: number, tickId: number?, frameContext: any?): { [string]: any }
			return self:_BuildAIRegistrationServices(registration, currentTime, tickId, frameContext)
		end,
		OnCancel = function()
			self:_RunAIRegistrationCallback(entityContext, registration, "OnCancel")
		end,
		OnRemoved = function()
			self:ClearAIRegistrationRuntimeState(registration.Entity)
			self:CleanupAIRegistration(registration, true)
			self:_RunAIRegistrationCallback(entityContext, registration, "OnRemoved")
		end,
		OnActionResult = function(actionResult: any)
			self:_RunAIRegistrationCallback(entityContext, registration, "OnActionResult", actionResult)
		end,
		OnActionStateChanged = function(actionState: any)
			self:WriteAIActionStateFromCombatState(registration.Entity, actionState, os.clock())
			self:_RunAIRegistrationCallback(entityContext, registration, "OnActionStateChanged", actionState)
		end,
	}
end

function EntityAICallbackAdapterService:CleanupAIRegistration(registration: any, removeRegistration: boolean)
	if not registration.IsCleanedUp then
		self:_CleanupResolver(registration.ServicesResolver, registration.Entity)
		self:_CleanupResolver(registration.FactsResolver, registration.Entity)
		registration.IsCleanedUp = true
	end

	if removeRegistration then
		self._aiEntityRegistry:RemoveAIRegistration(registration.Entity)
	end
end

function EntityAICallbackAdapterService:WriteAIRegistrationRuntimeState(
	entity: number,
	compiledActorType: any,
	profile: any,
	actorHandle: string
): Result.Result<boolean>
	return Result.Catch(function()
		local registeredAt = os.clock()
		local actorTypeResult = self._entityFactory:Set(entity, "AIActorType", {
			RuntimeKind = compiledActorType.RuntimeKind,
			ActorType = compiledActorType.ActorType,
		})
		if not actorTypeResult.success then
			return actorTypeResult
		end

		local runtimeProfileResult = self._entityFactory:Set(entity, "AIRuntimeProfile", {
			RuntimeProfileId = actorHandle,
			TickInterval = profile.TickInterval,
		})
		if not runtimeProfileResult.success then
			return runtimeProfileResult
		end

		local behaviorConfigResult = self._entityFactory:Set(entity, "AIBehaviorConfig", {
			BehaviorDefinition = profile.BehaviorDefinition,
			TickInterval = profile.TickInterval,
		})
		if not behaviorConfigResult.success then
			return behaviorConfigResult
		end

		return self._entityFactory:Set(entity, "AIRegistration", {
			ActorHandle = actorHandle,
			RegisteredAt = registeredAt,
		})
	end, "EntityAICallbackAdapterService:WriteAIRegistrationRuntimeState")
end

function EntityAICallbackAdapterService:WriteAIActionState(entity: number, actionState: any): Result.Result<boolean>
	return self._entityFactory:Set(entity, "AIActionState", actionState)
end

function EntityAICallbackAdapterService:WriteDefaultAIActionState(entity: number): Result.Result<boolean>
	return self:WriteAIActionState(entity, _BuildDefaultActionState(os.clock()))
end

function EntityAICallbackAdapterService:WriteAIActionStateFromCombatState(
	entity: number,
	combatActionState: any,
	timestamp: number
): Result.Result<boolean>
	return self:WriteAIActionState(entity, _MapCombatActionState(combatActionState, timestamp))
end

function EntityAICallbackAdapterService:ClearAIRegistrationRuntimeState(entity: number): Result.Result<boolean>
	return Result.Catch(function()
		for _, componentKey in ipairs({ "AIActionState", "AIRegistration", "AIBehaviorConfig", "AIRuntimeProfile", "AIActorType" }) do
			local removeResult = self._entityFactory:Remove(entity, componentKey)
			if not removeResult.success then
				return removeResult
			end
		end

		return Result.Ok(true)
	end, "EntityAICallbackAdapterService:ClearAIRegistrationRuntimeState")
end

function EntityAICallbackAdapterService:ReadAIActorHandle(entity: number): Result.Result<string?>
	return Result.Catch(function()
		local registrationResult = self._entityFactory:Get(entity, "AIRegistration")
		if not registrationResult.success or type(registrationResult.value) ~= "table" then
			return Result.Ok(nil)
		end

		local actorHandle = registrationResult.value.ActorHandle
		if type(actorHandle) ~= "string" or actorHandle == "" then
			return Result.Ok(nil)
		end

		return Result.Ok(actorHandle)
	end, "EntityAICallbackAdapterService:ReadAIActorHandle")
end

function EntityAICallbackAdapterService:ReadAIRegistrationRuntimeState(entity: number): Result.Result<any?>
	return Result.Catch(function()
		if not self._entityFactory:Exists(entity) then
			return Result.Ok(nil)
		end

		local state = {}
		local hasAnyState = false
		for _, componentKey in ipairs({ "AIActorType", "AIRuntimeProfile", "AIActionState", "AIBehaviorConfig", "AIRegistration" }) do
			local readResult = self._entityFactory:Get(entity, componentKey)
			if not readResult.success then
				continue
			end
			hasAnyState = hasAnyState or readResult.value ~= nil
			state[componentKey] = readResult.value
		end

		return Result.Ok(if hasAnyState then state else nil)
	end, "EntityAICallbackAdapterService:ReadAIRegistrationRuntimeState")
end

function EntityAICallbackAdapterService:_IsAIRegistrationActive(entityContext: any, registration: any): boolean
	local didCheck, isActive = pcall(registration.CompiledActorType.IsEntityActive, entityContext, registration.Entity)
	if didCheck then
		return isActive == true
	end

	self:_MentionAICallbackFailure(registration, "IsActive", isActive)
	return false
end

function EntityAICallbackAdapterService:_GetAIRegistrationActorLabel(entityContext: any, registration: any): string?
	local getActorLabel = registration.CompiledActorType.GetActorLabel
	if type(getActorLabel) ~= "function" then
		return nil
	end

	local didResolve, actorLabel = pcall(getActorLabel, entityContext, registration.Entity)
	if not didResolve or (actorLabel ~= nil and type(actorLabel) ~= "string") then
		return nil
	end

	return actorLabel
end

function EntityAICallbackAdapterService:_BuildAIRegistrationFacts(registration: any, currentTime: number): { [string]: any }
	local factsResolver = registration.FactsResolver
	local buildFacts = if type(factsResolver) == "table" then factsResolver.BuildFacts else factsResolver
	if type(buildFacts) ~= "function" then
		return {}
	end

	local didBuild, facts
	if type(factsResolver) == "table" then
		didBuild, facts = pcall(buildFacts, factsResolver, registration.Entity, currentTime)
	else
		didBuild, facts = pcall(buildFacts, registration.Entity, currentTime)
	end

	if didBuild and type(facts) == "table" then
		return facts
	end

	self:_MentionAICallbackFailure(registration, "BuildFacts", facts)
	return {}
end

function EntityAICallbackAdapterService:_BuildAIRegistrationServices(
	registration: any,
	currentTime: number,
	tickId: number?,
	frameContext: any?
): { [string]: any }
	local servicesResolver = registration.ServicesResolver
	local buildServices = if type(servicesResolver) == "table" then servicesResolver.BuildServices else servicesResolver
	if type(buildServices) ~= "function" then
		return {}
	end

	local didBuild, services
	if type(servicesResolver) == "table" then
		didBuild, services = pcall(buildServices, servicesResolver, registration.Entity, currentTime, tickId, frameContext)
	else
		didBuild, services = pcall(buildServices, registration.Entity, currentTime, tickId, frameContext)
	end

	if didBuild and type(services) == "table" then
		return services
	end

	self:_MentionAICallbackFailure(registration, "BuildServices", services)
	return {}
end

function EntityAICallbackAdapterService:_RunAIRegistrationCallback(
	entityContext: any,
	registration: any,
	callbackName: string,
	callbackArgument: any?
)
	local callback = registration.CompiledActorType[callbackName]
	if type(callback) ~= "function" then
		return
	end

	local didRun, callbackError
	if callbackArgument == nil then
		didRun, callbackError = pcall(callback, entityContext, registration.Entity)
	else
		didRun, callbackError = pcall(callback, entityContext, registration.Entity, callbackArgument)
	end

	if not didRun then
		self:_MentionAICallbackFailure(registration, callbackName, callbackError)
	end
end

function EntityAICallbackAdapterService:_CleanupResolver(resolver: any?, entity: number)
	if type(resolver) ~= "table" then
		return
	end

	if type(resolver.Cleanup) == "function" then
		pcall(resolver.Cleanup, resolver, entity)
	end
	if type(resolver.Invalidate) == "function" then
		pcall(resolver.Invalidate, resolver, entity)
	end
end

function EntityAICallbackAdapterService:_MentionAICallbackFailure(registration: any, stage: string, causeMessage: any?)
	Result.MentionError("EntityAICallbackAdapterService:AI", "AI callback failed", {
		ActorType = registration.CompiledActorType.ActorType,
		ActorHandle = registration.ActorHandle,
		Entity = registration.Entity,
		RuntimeKind = registration.RuntimeKind,
		Stage = stage,
		CauseMessage = causeMessage,
	}, "EntityAICallbackFailed")
end

return EntityAICallbackAdapterService
