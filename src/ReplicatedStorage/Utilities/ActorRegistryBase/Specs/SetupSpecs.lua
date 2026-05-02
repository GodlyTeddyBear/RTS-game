--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Spec = require(ReplicatedStorage.Utilities.Specification)
local Errors = require(script.Parent.Parent.Errors)

export type TRegistrySetupCandidate = {
	Registry: any,
}

export type TRegistryHookCandidate = {
	Registry: any,
	HookName: string,
	BaseMethod: any?,
}

export type TRegistryMethodCandidate = {
	Registry: any,
	MethodName: string,
}

local HasActorTypesTable = Spec.new(
	"InvalidActorRegistrySetup",
	Errors.INVALID_SETUP_MISSING_ACTOR_TYPES,
	function(candidate: TRegistrySetupCandidate): boolean
		return type(candidate.Registry._actorTypes) == "table"
	end
)

local HasRecordsByRuntimeIdTable = Spec.new(
	"InvalidActorRegistrySetup",
	Errors.INVALID_SETUP_MISSING_RECORDS_BY_RUNTIME_ID,
	function(candidate: TRegistrySetupCandidate): boolean
		return type(candidate.Registry._recordsByRuntimeId) == "table"
	end
)

local HasRuntimeIdsByHandleTable = Spec.new(
	"InvalidActorRegistrySetup",
	Errors.INVALID_SETUP_MISSING_RUNTIME_IDS_BY_HANDLE,
	function(candidate: TRegistrySetupCandidate): boolean
		return type(candidate.Registry._runtimeIdsByHandle) == "table"
	end
)

local HasRuntimeIdsByActorTypeTable = Spec.new(
	"InvalidActorRegistrySetup",
	Errors.INVALID_SETUP_MISSING_RUNTIME_IDS_BY_ACTOR_TYPE,
	function(candidate: TRegistrySetupCandidate): boolean
		return type(candidate.Registry._runtimeIdsByActorType) == "table"
	end
)

local HasPendingActorPayloadsTable = Spec.new(
	"InvalidActorRegistrySetup",
	Errors.INVALID_SETUP_MISSING_PENDING_ACTOR_PAYLOADS,
	function(candidate: TRegistrySetupCandidate): boolean
		return type(candidate.Registry._pendingActorPayloadsByHandle) == "table"
	end
)

local HasNumericNextRuntimeId = Spec.new(
	"InvalidActorRegistrySetup",
	Errors.INVALID_SETUP_NON_NUMERIC_NEXT_RUNTIME_ID,
	function(candidate: TRegistrySetupCandidate): boolean
		return type(candidate.Registry._nextRuntimeId) == "number"
	end
)

local HasBooleanRuntimeStartedFlag = Spec.new(
	"InvalidActorRegistrySetup",
	Errors.INVALID_SETUP_NON_BOOLEAN_RUNTIME_STARTED_FLAG,
	function(candidate: TRegistrySetupCandidate): boolean
		return type(candidate.Registry._runtimeStarted) == "boolean"
	end
)

local HasHookFunction = Spec.new(
	"InvalidActorRegistrySetup",
	Errors.INVALID_SETUP_MISSING_HOOK,
	function(candidate: TRegistryHookCandidate): boolean
		return type(candidate.Registry[candidate.HookName]) == "function"
	end
)

local HasOverriddenHook = Spec.new(
	"InvalidActorRegistrySetup",
	Errors.INVALID_SETUP_MISSING_OVERRIDE_HOOK,
	function(candidate: TRegistryHookCandidate): boolean
		return candidate.Registry[candidate.HookName] ~= candidate.BaseMethod
	end
)

local HasRuntimeMethod = Spec.new(
	"InvalidActorRegistrySetup",
	Errors.INVALID_SETUP_MISSING_RUNTIME_METHOD,
	function(candidate: TRegistryMethodCandidate): boolean
		return type(candidate.Registry[candidate.MethodName]) == "function"
	end
)

return table.freeze({
	HasCoreState = Spec.All({
		HasActorTypesTable,
		HasRecordsByRuntimeIdTable,
		HasRuntimeIdsByHandleTable,
		HasRuntimeIdsByActorTypeTable,
		HasPendingActorPayloadsTable,
		HasNumericNextRuntimeId,
		HasBooleanRuntimeStartedFlag,
	}),
	HasHookFunction = HasHookFunction,
	HasOverriddenHook = HasOverriddenHook,
	HasRuntimeMethod = HasRuntimeMethod,
})
