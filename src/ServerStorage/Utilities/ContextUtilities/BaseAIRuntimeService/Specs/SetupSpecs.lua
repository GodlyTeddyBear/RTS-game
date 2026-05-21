--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Spec = require(ReplicatedStorage.Utilities.Specification)
local Errors = require(script.Parent.Parent.Errors)

export type TSetupCandidate = {
	RuntimeService: any,
	ExpectedActorRegistryService: any,
}

export type TActorRegistryMethodCandidate = {
	ActorRegistryService: any,
	MethodName: string,
}

export type TRuntimeStartedCandidate = {
	RuntimeStarted: any,
}

local HasRuntimeLabel = Spec.new(
	"InvalidAIRuntimeSetup",
	Errors.INVALID_SETUP_MISSING_RUNTIME_LABEL,
	function(candidate: TSetupCandidate): boolean
		local runtimeService = candidate.RuntimeService
		return type(runtimeService._runtimeLabel) == "string" and runtimeService._runtimeLabel ~= ""
	end
)

local HasRuntimeContextLabel = Spec.new(
	"InvalidAIRuntimeSetup",
	Errors.INVALID_SETUP_MISSING_RUNTIME_CONTEXT_LABEL,
	function(candidate: TSetupCandidate): boolean
		local runtimeService = candidate.RuntimeService
		return type(runtimeService._runtimeContextLabel) == "string" and runtimeService._runtimeContextLabel ~= ""
	end
)

local HasRuntimeDisplayName = Spec.new(
	"InvalidAIRuntimeSetup",
	Errors.INVALID_SETUP_MISSING_RUNTIME_DISPLAY_NAME,
	function(candidate: TSetupCandidate): boolean
		local runtimeService = candidate.RuntimeService
		return type(runtimeService._runtimeDisplayName) == "string" and runtimeService._runtimeDisplayName ~= ""
	end
)

local HasActorRegistryServiceName = Spec.new(
	"InvalidAIRuntimeSetup",
	Errors.INVALID_SETUP_MISSING_ACTOR_REGISTRY_SERVICE_NAME,
	function(candidate: TSetupCandidate): boolean
		local runtimeService = candidate.RuntimeService
		return type(runtimeService._actorRegistryServiceName) == "string" and runtimeService._actorRegistryServiceName ~= ""
	end
)

local HasBaseHooksTable = Spec.new(
	"InvalidAIRuntimeSetup",
	Errors.INVALID_SETUP_MISSING_BASE_HOOKS,
	function(candidate: TSetupCandidate): boolean
		return type(candidate.RuntimeService._baseHooks) == "table"
	end
)

local HasErrorsTable = Spec.new(
	"InvalidAIRuntimeSetup",
	Errors.INVALID_SETUP_MISSING_ERRORS,
	function(candidate: TSetupCandidate): boolean
		return type(candidate.RuntimeService._errors) == "table"
	end
)

local HasRuntimeAlreadyStartedError = Spec.new(
	"InvalidAIRuntimeSetup",
	Errors.INVALID_SETUP_MISSING_RUNTIME_ALREADY_STARTED_ERROR,
	function(candidate: TSetupCandidate): boolean
		local errors = candidate.RuntimeService._errors
		return type(errors) == "table" and type(errors.RUNTIME_ALREADY_STARTED) == "string" and errors.RUNTIME_ALREADY_STARTED ~= ""
	end
)

local HasRuntimeStartFailedError = Spec.new(
	"InvalidAIRuntimeSetup",
	Errors.INVALID_SETUP_MISSING_RUNTIME_START_FAILED_ERROR,
	function(candidate: TSetupCandidate): boolean
		local errors = candidate.RuntimeService._errors
		return type(errors) == "table" and type(errors.RUNTIME_START_FAILED) == "string" and errors.RUNTIME_START_FAILED ~= ""
	end
)

local HasRuntimeNotStartedError = Spec.new(
	"InvalidAIRuntimeSetup",
	Errors.INVALID_SETUP_MISSING_RUNTIME_NOT_STARTED_ERROR,
	function(candidate: TSetupCandidate): boolean
		local errors = candidate.RuntimeService._errors
		return type(errors) == "table" and type(errors.RUNTIME_NOT_STARTED) == "string" and errors.RUNTIME_NOT_STARTED ~= ""
	end
)

local HasNilRuntimeObject = Spec.new(
	"InvalidAIRuntimeSetup",
	Errors.INVALID_SETUP_RUNTIME_OBJECT_NOT_NIL,
	function(candidate: TSetupCandidate): boolean
		return candidate.RuntimeService._runtime == nil
	end
)

local HasResolvedActorRegistryService = Spec.new(
	"InvalidAIRuntimeSetup",
	Errors.INVALID_SETUP_MISSING_RESOLVED_ACTOR_REGISTRY,
	function(candidate: TSetupCandidate): boolean
		return candidate.RuntimeService._actorRegistryService ~= nil
	end
)

local HasExpectedActorRegistryService = Spec.new(
	"InvalidAIRuntimeSetup",
	Errors.INVALID_SETUP_ACTOR_REGISTRY_MISMATCH,
	function(candidate: TSetupCandidate): boolean
		return candidate.RuntimeService._actorRegistryService == candidate.ExpectedActorRegistryService
	end
)

local HasRequiredActorRegistryMethod = Spec.new(
	"InvalidAIRuntimeSetup",
	Errors.INVALID_SETUP_MISSING_ACTOR_REGISTRY_METHOD,
	function(candidate: TActorRegistryMethodCandidate): boolean
		return type(candidate.ActorRegistryService[candidate.MethodName]) == "function"
	end
)

local HasBooleanRuntimeStartedFlag = Spec.new(
	"InvalidAIRuntimeSetup",
	Errors.INVALID_SETUP_NON_BOOLEAN_RUNTIME_FLAG,
	function(candidate: TRuntimeStartedCandidate): boolean
		return type(candidate.RuntimeStarted) == "boolean"
	end
)

local HasStoppedRuntimeFlag = Spec.new(
	"InvalidAIRuntimeSetup",
	Errors.INVALID_SETUP_RUNTIME_ALREADY_STARTED,
	function(candidate: TRuntimeStartedCandidate): boolean
		return candidate.RuntimeStarted == false
	end
)

return table.freeze({
	HasConfigShape = Spec.All({
		HasRuntimeLabel,
		HasRuntimeContextLabel,
		HasRuntimeDisplayName,
		HasActorRegistryServiceName,
		HasBaseHooksTable,
		HasErrorsTable,
		HasRuntimeAlreadyStartedError,
		HasRuntimeStartFailedError,
		HasRuntimeNotStartedError,
	}),
	HasCleanStartupState = Spec.All({
		HasNilRuntimeObject,
		HasResolvedActorRegistryService,
		HasExpectedActorRegistryService,
	}),
	HasRequiredActorRegistryMethod = HasRequiredActorRegistryMethod,
	HasBooleanRuntimeStartedFlag = HasBooleanRuntimeStartedFlag,
	HasStoppedRuntimeFlag = HasStoppedRuntimeFlag,
})
