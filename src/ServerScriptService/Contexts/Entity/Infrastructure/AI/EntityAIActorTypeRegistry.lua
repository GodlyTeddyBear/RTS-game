--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Result = require(ReplicatedStorage.Utilities.Result)

local Errors = require(script.Parent.Parent.Parent.Errors)

type TEntityAIProfile = {
	BehaviorDefinition: any,
	TickInterval: number,
}

type TResolverDependencyContract = {
	DependencyMode: "EntityContextOnly",
	AllowsRuntimeServices: boolean?,
	DeclaredDependencies: { string }?,
}

export type TEntityAIActorTypePayload = {
	RuntimeKind: "Combat",
	ActorType: string,
	Conditions: { [string]: any },
	Commands: { [string]: any },
	Executors: { [string]: any },
	SemanticRequirements: any?,
	RuntimeBinding: any?,
	RuntimeOwner: any?,
	ResolveProfile: (entityContext: any, entity: number) -> TEntityAIProfile?,
	CreateFactsResolver: ((entityContext: any) -> any?)?,
	CreateServicesResolver: ((entityContext: any, runtimeServices: any) -> any?)?,
	BuildActorHandle: (entityContext: any, entity: number) -> string,
	IsEntityActive: (entityContext: any, entity: number) -> boolean,
	OnCancel: ((entityContext: any, entity: number) -> ())?,
	OnRemoved: ((entityContext: any, entity: number) -> ())?,
	OnActionResult: ((entityContext: any, entity: number, actionResult: any) -> ())?,
	OnActionStateChanged: ((entityContext: any, entity: number, actionState: any) -> ())?,
	GetActorLabel: ((entityContext: any, entity: number) -> string?)?,
	DependencyContract: TResolverDependencyContract?,
}

export type TCompiledEntityAIActorType = {
	RuntimeKind: "Combat",
	ActorType: string,
	Conditions: { [string]: any },
	Commands: { [string]: any },
	Executors: { [string]: any },
	SemanticRequirements: any?,
	RuntimeBinding: any?,
	RuntimeOwner: any?,
	ResolveProfile: (entityContext: any, entity: number) -> TEntityAIProfile?,
	CreateFactsResolver: ((entityContext: any) -> any?)?,
	CreateServicesResolver: ((entityContext: any, runtimeServices: any) -> any?)?,
	BuildActorHandle: (entityContext: any, entity: number) -> string,
	IsEntityActive: (entityContext: any, entity: number) -> boolean,
	OnCancel: ((entityContext: any, entity: number) -> ())?,
	OnRemoved: ((entityContext: any, entity: number) -> ())?,
	OnActionResult: ((entityContext: any, entity: number, actionResult: any) -> ())?,
	OnActionStateChanged: ((entityContext: any, entity: number, actionState: any) -> ())?,
	GetActorLabel: ((entityContext: any, entity: number) -> string?)?,
	DependencyContract: TResolverDependencyContract,
}

local EntityAIActorTypeRegistry = {}
EntityAIActorTypeRegistry.__index = EntityAIActorTypeRegistry

local function _BuildActorTypeKey(runtimeKind: string, actorType: string): string
	return runtimeKind .. ":" .. actorType
end

local DEFAULT_DEPENDENCY_CONTRACT: TResolverDependencyContract = table.freeze({
	DependencyMode = "EntityContextOnly",
	AllowsRuntimeServices = true,
	DeclaredDependencies = table.freeze({ "EntityContext", "RuntimeServices" }),
})

local function _DeepClone(value: any): any
	if type(value) ~= "table" then
		return value
	end

	local clone = {}
	for key, nestedValue in pairs(value) do
		clone[key] = _DeepClone(nestedValue)
	end
	return clone
end

local function _CompileDependencyContract(
	dependencyContract: TResolverDependencyContract?
): Result.Result<TResolverDependencyContract>
	if dependencyContract == nil then
		return Result.Ok(DEFAULT_DEPENDENCY_CONTRACT)
	end

	if type(dependencyContract) ~= "table" then
		return Result.Err("InvalidAIActorType", Errors.INVALID_AI_ACTOR_TYPE, {
			Reason = "InvalidDependencyContract",
		})
	end

	if dependencyContract.DependencyMode ~= "EntityContextOnly" then
		return Result.Err("InvalidAIActorType", Errors.INVALID_AI_ACTOR_TYPE, {
			Reason = "UnsupportedDependencyMode",
			DependencyMode = dependencyContract.DependencyMode,
		})
	end

	if dependencyContract.AllowsRuntimeServices ~= nil and type(dependencyContract.AllowsRuntimeServices) ~= "boolean" then
		return Result.Err("InvalidAIActorType", Errors.INVALID_AI_ACTOR_TYPE, {
			Reason = "InvalidAllowsRuntimeServices",
		})
	end

	local declaredDependencies = dependencyContract.DeclaredDependencies
	if declaredDependencies ~= nil then
		if type(declaredDependencies) ~= "table" then
			return Result.Err("InvalidAIActorType", Errors.INVALID_AI_ACTOR_TYPE, {
				Reason = "InvalidDeclaredDependencies",
			})
		end

		for _, dependencyName in ipairs(declaredDependencies) do
			if dependencyName ~= "EntityContext" and dependencyName ~= "RuntimeServices" then
				return Result.Err("InvalidAIActorType", Errors.INVALID_AI_ACTOR_TYPE, {
					Reason = "UnsupportedDeclaredDependency",
					DependencyName = dependencyName,
				})
			end

			if dependencyName == "RuntimeServices" and dependencyContract.AllowsRuntimeServices == false then
				return Result.Err("InvalidAIActorType", Errors.INVALID_AI_ACTOR_TYPE, {
					Reason = "RuntimeServicesDependencyNotAllowed",
				})
			end
		end
	end

	local allowsRuntimeServices = dependencyContract.AllowsRuntimeServices ~= false
	local fallbackDependencies = if allowsRuntimeServices
		then { "EntityContext", "RuntimeServices" }
		else { "EntityContext" }

	return Result.Ok(table.freeze({
		DependencyMode = dependencyContract.DependencyMode,
		AllowsRuntimeServices = allowsRuntimeServices,
		DeclaredDependencies = table.freeze(_DeepClone(declaredDependencies or fallbackDependencies)),
	}))
end

function EntityAIActorTypeRegistry.new()
	local self = setmetatable({}, EntityAIActorTypeRegistry)
	self._compiledByKey = {}
	self._isRegistrationClosed = false
	return self
end

function EntityAIActorTypeRegistry:Init(_registry: any, _name: string)
end

function EntityAIActorTypeRegistry:RegisterActorType(
	payload: TEntityAIActorTypePayload
): Result.Result<TCompiledEntityAIActorType>
	return Result.Catch(function()
		if self._isRegistrationClosed then
			return Result.Err("InvalidAIActorType", Errors.INVALID_AI_ACTOR_TYPE, {
				Reason = "RegistrationClosed",
			})
		end

		if type(payload) ~= "table" then
			return Result.Err("InvalidAIActorType", Errors.INVALID_AI_ACTOR_TYPE, {})
		end

		if payload.RuntimeKind ~= "Combat" then
			return Result.Err("UnsupportedAIRuntimeKind", Errors.UNSUPPORTED_AI_RUNTIME_KIND, {
				RuntimeKind = payload.RuntimeKind,
			})
		end

		if type(payload.ActorType) ~= "string" or payload.ActorType == "" then
			return Result.Err("InvalidAIActorType", Errors.INVALID_AI_ACTOR_TYPE, {})
		end

		if
			type(payload.Conditions) ~= "table"
			or type(payload.Commands) ~= "table"
			or type(payload.Executors) ~= "table"
			or type(payload.ResolveProfile) ~= "function"
			or type(payload.BuildActorHandle) ~= "function"
			or type(payload.IsEntityActive) ~= "function"
		then
			return Result.Err("InvalidAIActorType", Errors.INVALID_AI_ACTOR_TYPE, {
				ActorType = payload.ActorType,
				RuntimeKind = payload.RuntimeKind,
			})
		end

		local actorTypeKey = _BuildActorTypeKey(payload.RuntimeKind, payload.ActorType)
		if self._compiledByKey[actorTypeKey] ~= nil then
			return Result.Err("DuplicateAIActorType", Errors.DUPLICATE_AI_ACTOR_TYPE, {
				ActorType = payload.ActorType,
				RuntimeKind = payload.RuntimeKind,
			})
		end

		local dependencyContractResult = _CompileDependencyContract(payload.DependencyContract)
		if not dependencyContractResult.success then
			return dependencyContractResult
		end

		local compiledActorType: TCompiledEntityAIActorType = table.freeze({
			RuntimeKind = payload.RuntimeKind,
			ActorType = payload.ActorType,
			Conditions = payload.Conditions,
			Commands = payload.Commands,
			Executors = payload.Executors,
			SemanticRequirements = payload.SemanticRequirements,
			RuntimeBinding = payload.RuntimeBinding,
			RuntimeOwner = payload.RuntimeOwner,
			ResolveProfile = payload.ResolveProfile,
			CreateFactsResolver = payload.CreateFactsResolver,
			CreateServicesResolver = payload.CreateServicesResolver,
			BuildActorHandle = payload.BuildActorHandle,
			IsEntityActive = payload.IsEntityActive,
			OnCancel = payload.OnCancel,
			OnRemoved = payload.OnRemoved,
			OnActionResult = payload.OnActionResult,
			OnActionStateChanged = payload.OnActionStateChanged,
			GetActorLabel = payload.GetActorLabel,
			DependencyContract = dependencyContractResult.value,
		})

		self._compiledByKey[actorTypeKey] = compiledActorType
		return Result.Ok(compiledActorType)
	end, "EntityAIActorTypeRegistry:RegisterActorType")
end

function EntityAIActorTypeRegistry:GetCompiledActorType(
	runtimeKind: string,
	actorType: string
): TCompiledEntityAIActorType?
	return self._compiledByKey[_BuildActorTypeKey(runtimeKind, actorType)]
end

function EntityAIActorTypeRegistry:RemoveCompiledActorType(runtimeKind: string, actorType: string)
	self._compiledByKey[_BuildActorTypeKey(runtimeKind, actorType)] = nil
end

function EntityAIActorTypeRegistry:CloseRegistration(): Result.Result<boolean>
	return Result.Catch(function()
		self._isRegistrationClosed = true
		return Result.Ok(true)
	end, "EntityAIActorTypeRegistry:CloseRegistration")
end

function EntityAIActorTypeRegistry:ValidateReady(): Result.Result<boolean>
	if not self._isRegistrationClosed then
		return Result.Err("InvalidAIActorType", Errors.INVALID_AI_ACTOR_TYPE, {
			Reason = "RegistrationStillOpen",
		})
	end

	return Result.Ok(true)
end

function EntityAIActorTypeRegistry:GetStatus(): any
	local actorTypeCount = 0
	local dependencyMode: string = DEFAULT_DEPENDENCY_CONTRACT.DependencyMode
	local allowsRuntimeServices = false

	for _ in pairs(self._compiledByKey) do
		actorTypeCount += 1
	end

	for _, compiledActorType in pairs(self._compiledByKey) do
		local dependencyContract = compiledActorType.DependencyContract
		if dependencyContract ~= nil and dependencyContract.DependencyMode ~= dependencyMode then
			dependencyMode = "Mixed"
		end
		if dependencyContract ~= nil and dependencyContract.AllowsRuntimeServices then
			allowsRuntimeServices = true
		end
	end

	return table.freeze({
		RegistrationClosed = self._isRegistrationClosed,
		ActorTypeCount = actorTypeCount,
		DependencyMode = dependencyMode,
		AllowsRuntimeServices = allowsRuntimeServices,
	})
end

return EntityAIActorTypeRegistry
