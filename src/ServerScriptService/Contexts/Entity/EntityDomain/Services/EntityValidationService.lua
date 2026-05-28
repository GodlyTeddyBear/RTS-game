--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Result = require(ReplicatedStorage.Utilities.Result)

local EntityPayloadSpecs = require(script.Parent.Parent.Specs.EntityPayloadSpecs)
local Errors = require(script.Parent.Parent.Parent.Errors)

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

local EntityValidationService = {}
EntityValidationService.__index = EntityValidationService

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

return EntityValidationService
