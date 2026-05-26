--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Result = require(ReplicatedStorage.Utilities.Result)

local EntityPayloadSpecs = require(script.Parent.Parent.Specs.EntityPayloadSpecs)
local Errors = require(script.Parent.Parent.Parent.Errors)

local DEFAULT_DEPENDENCY_CONTRACT = table.freeze({
	DependencyMode = "EntityContextOnly",
	AllowsRuntimeServices = true,
	DeclaredDependencies = table.freeze({ "EntityContext", "RuntimeServices" }),
})

local INSTANCE_BINDING_OPTIONAL_CALLBACKS = {
	"BuildActorKind",
	"ResolveParentFolder",
	"PrepareInstance",
	"BuildRevealAttributes",
	"BuildRevealTags",
	"BuildRevealClearAttributes",
	"BuildName",
}

local SYNC_OPTIONAL_CALLBACKS = {
	"SyncAll",
	"SyncEntity",
	"PollEntity",
	"QuerySyncEntities",
	"QueryPollEntities",
}

local REPLICATION_OPTIONAL_CALLBACKS = {
	"RegisterEntity",
	"UnregisterEntity",
	"BuildSchema",
}

export type TResolverDependencyContract = {
	DependencyMode: "EntityContextOnly",
	AllowsRuntimeServices: boolean?,
	DeclaredDependencies: { string }?,
}

local EntityValidationService = {}
EntityValidationService.__index = EntityValidationService

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

local function _EnsureOptionalCallbacks(
	payload: any,
	featureName: string,
	callbackNames: { string },
	errorType: string,
	errorMessage: string
): Result.Result<boolean>
	for _, callbackName in ipairs(callbackNames) do
		if not EntityPayloadSpecs.IsOptionalFunction(payload[callbackName]) then
			return Result.Err(errorType, errorMessage, {
				FeatureName = featureName,
				Key = callbackName,
			})
		end
	end

	return Result.Ok(true)
end

function EntityValidationService.new()
	return setmetatable({}, EntityValidationService)
end

function EntityValidationService:Init(_registry: any, _name: string)
	return
end

function EntityValidationService:ValidateLifecycleExpectation(
	methodName: string,
	currentState: string,
	expectedStates: { string }
): Result.Result<boolean>
	for _, expectedState in ipairs(expectedStates) do
		if currentState == expectedState then
			return Result.Ok(true)
		end
	end

	return Result.Err("InvalidEntityLifecycleState", Errors.INVALID_LIFECYCLE_STATE, {
		MethodName = methodName,
		CurrentState = currentState,
		ExpectedStates = table.clone(expectedStates),
	})
end

function EntityValidationService:ValidateQuerySpec(querySpec: any): Result.Result<boolean>
	if EntityPayloadSpecs.IsValidQuerySpec(querySpec) then
		return Result.Ok(true)
	end

	return Result.Err("InvalidQuery", Errors.INVALID_QUERY, {
		QuerySpec = querySpec,
	})
end

function EntityValidationService:ValidateInstanceBinding(featureName: string, binding: any): Result.Result<any>
	if not EntityPayloadSpecs.IsNonEmptyFeatureName(featureName) or not EntityPayloadSpecs.IsTable(binding) then
		return Result.Err("InvalidInstanceBinding", Errors.INVALID_INSTANCE_BINDING, {
			FeatureName = featureName,
		})
	end

	if not EntityPayloadSpecs.HasMatchingFeatureName(binding, featureName) then
		return Result.Err("InvalidInstanceBinding", Errors.INVALID_INSTANCE_BINDING, {
			FeatureName = featureName,
			Reason = "FeatureNameMismatch",
		})
	end

	if not EntityPayloadSpecs.IsRequiredFunction(binding.ResolveAsset) then
		return Result.Err("InvalidInstanceBinding", Errors.INVALID_INSTANCE_BINDING, {
			FeatureName = featureName,
			Key = "ResolveAsset",
			IsRequired = true,
		})
	end

	local callbackResult = _EnsureOptionalCallbacks(
		binding,
		featureName,
		INSTANCE_BINDING_OPTIONAL_CALLBACKS,
		"InvalidInstanceBinding",
		Errors.INVALID_INSTANCE_BINDING
	)
	if not callbackResult.success then
		return callbackResult
	end

	return Result.Ok(table.freeze({
		FeatureName = featureName,
		BuildActorKind = binding.BuildActorKind,
		ResolveAsset = binding.ResolveAsset,
		ResolveParentFolder = binding.ResolveParentFolder,
		PrepareInstance = binding.PrepareInstance,
		BuildRevealAttributes = binding.BuildRevealAttributes,
		BuildRevealTags = binding.BuildRevealTags,
		BuildRevealClearAttributes = binding.BuildRevealClearAttributes,
		BuildName = binding.BuildName,
	}))
end

function EntityValidationService:ValidateSyncContributor(featureName: string, payload: any): Result.Result<any>
	if not EntityPayloadSpecs.IsNonEmptyFeatureName(featureName) or not EntityPayloadSpecs.IsTable(payload) then
		return Result.Err("InvalidSyncContributor", Errors.INVALID_SYNC_CONTRIBUTOR, {
			FeatureName = featureName,
		})
	end

	if not EntityPayloadSpecs.HasMatchingFeatureName(payload, featureName) then
		return Result.Err("InvalidSyncContributor", Errors.INVALID_SYNC_CONTRIBUTOR, {
			FeatureName = featureName,
			Reason = "FeatureNameMismatch",
		})
	end

	local callbackResult = _EnsureOptionalCallbacks(
		payload,
		featureName,
		SYNC_OPTIONAL_CALLBACKS,
		"InvalidSyncContributor",
		Errors.INVALID_SYNC_CONTRIBUTOR
	)
	if not callbackResult.success then
		return callbackResult
	end

	return Result.Ok(table.freeze({
		FeatureName = featureName,
		SyncAll = payload.SyncAll,
		SyncEntity = payload.SyncEntity,
		PollEntity = payload.PollEntity,
		QuerySyncEntities = payload.QuerySyncEntities,
		QueryPollEntities = payload.QueryPollEntities,
	}))
end

function EntityValidationService:ValidateReplicationSurface(featureName: string, payload: any): Result.Result<any>
	if not EntityPayloadSpecs.IsNonEmptyFeatureName(featureName) or not EntityPayloadSpecs.IsTable(payload) then
		return Result.Err("InvalidReplicationSurface", Errors.INVALID_REPLICATION_SURFACE, {
			FeatureName = featureName,
		})
	end

	if featureName == "Base" then
		return Result.Err("UnsupportedReplicationFeature", Errors.UNSUPPORTED_REPLICATION_FEATURE, {
			FeatureName = featureName,
		})
	end

	if not EntityPayloadSpecs.HasMatchingFeatureName(payload, featureName) then
		return Result.Err("InvalidReplicationSurface", Errors.INVALID_REPLICATION_SURFACE, {
			FeatureName = featureName,
			Reason = "FeatureNameMismatch",
		})
	end

	local callbackResult = _EnsureOptionalCallbacks(
		payload,
		featureName,
		REPLICATION_OPTIONAL_CALLBACKS,
		"InvalidReplicationSurface",
		Errors.INVALID_REPLICATION_SURFACE
	)
	if not callbackResult.success then
		return callbackResult
	end

	return Result.Ok(table.freeze({
		FeatureName = featureName,
		SharedComponents = type(payload.SharedComponents) == "table" and table.clone(payload.SharedComponents) or nil,
		SharedTags = type(payload.SharedTags) == "table" and table.clone(payload.SharedTags) or nil,
		RegisterEntity = payload.RegisterEntity,
		UnregisterEntity = payload.UnregisterEntity,
		BuildSchema = payload.BuildSchema,
	}))
end

function EntityValidationService:ValidateDependencyContract(
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

	if not EntityPayloadSpecs.IsSupportedDependencyMode(dependencyContract.DependencyMode) then
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
			if not EntityPayloadSpecs.IsSupportedDeclaredDependency(dependencyName) then
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
		DependencyMode = "EntityContextOnly",
		AllowsRuntimeServices = allowsRuntimeServices,
		DeclaredDependencies = table.freeze(_DeepClone(declaredDependencies or fallbackDependencies)),
	}))
end

function EntityValidationService:ValidateAIActorTypePayload(payload: any): Result.Result<any>
	if not EntityPayloadSpecs.IsTable(payload) then
		return Result.Err("InvalidAIActorType", Errors.INVALID_AI_ACTOR_TYPE, {})
	end

	if not EntityPayloadSpecs.IsSupportedAIRuntimeKind(payload.RuntimeKind) then
		return Result.Err("UnsupportedAIRuntimeKind", Errors.UNSUPPORTED_AI_RUNTIME_KIND, {
			RuntimeKind = payload.RuntimeKind,
		})
	end

	if not EntityPayloadSpecs.IsNonEmptyFeatureName(payload.ActorType) then
		return Result.Err("InvalidAIActorType", Errors.INVALID_AI_ACTOR_TYPE, {})
	end

	if
		not EntityPayloadSpecs.IsTable(payload.Conditions)
		or not EntityPayloadSpecs.IsTable(payload.Commands)
		or not EntityPayloadSpecs.IsTable(payload.Executors)
		or not EntityPayloadSpecs.IsRequiredFunction(payload.ResolveProfile)
		or not EntityPayloadSpecs.IsRequiredFunction(payload.BuildActorHandle)
		or not EntityPayloadSpecs.IsRequiredFunction(payload.IsEntityActive)
	then
		return Result.Err("InvalidAIActorType", Errors.INVALID_AI_ACTOR_TYPE, {
			ActorType = payload.ActorType,
			RuntimeKind = payload.RuntimeKind,
		})
	end

	local dependencyContractResult = self:ValidateDependencyContract(payload.DependencyContract)
	if not dependencyContractResult.success then
		return dependencyContractResult
	end

	return Result.Ok(table.freeze({
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
	}))
end

return EntityValidationService
