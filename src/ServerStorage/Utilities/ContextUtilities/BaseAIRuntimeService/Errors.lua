--!strict

local Errors = {}

Errors.INVALID_SETUP_MISSING_RUNTIME_LABEL = "BaseAIRuntimeService setup is missing _runtimeLabel"
Errors.INVALID_SETUP_MISSING_RUNTIME_CONTEXT_LABEL = "BaseAIRuntimeService setup is missing _runtimeContextLabel"
Errors.INVALID_SETUP_MISSING_RUNTIME_DISPLAY_NAME = "BaseAIRuntimeService setup is missing _runtimeDisplayName"
Errors.INVALID_SETUP_MISSING_ACTOR_REGISTRY_SERVICE_NAME = "BaseAIRuntimeService setup is missing _actorRegistryServiceName"
Errors.INVALID_SETUP_MISSING_BASE_HOOKS = "BaseAIRuntimeService setup is missing _baseHooks"
Errors.INVALID_SETUP_MISSING_ERRORS = "BaseAIRuntimeService setup is missing _errors"
Errors.INVALID_SETUP_MISSING_RUNTIME_ALREADY_STARTED_ERROR = "BaseAIRuntimeService setup is missing Errors.RUNTIME_ALREADY_STARTED"
Errors.INVALID_SETUP_MISSING_RUNTIME_START_FAILED_ERROR = "BaseAIRuntimeService setup is missing Errors.RUNTIME_START_FAILED"
Errors.INVALID_SETUP_MISSING_RUNTIME_NOT_STARTED_ERROR = "BaseAIRuntimeService setup is missing Errors.RUNTIME_NOT_STARTED"
Errors.INVALID_SETUP_RUNTIME_OBJECT_NOT_NIL = "BaseAIRuntimeService runtime object must be nil before startup"
Errors.INVALID_SETUP_MISSING_RESOLVED_ACTOR_REGISTRY = "BaseAIRuntimeService actor registry service was not resolved during Init"
Errors.INVALID_SETUP_ACTOR_REGISTRY_MISMATCH = "BaseAIRuntimeService actor registry service does not match expected registry"
Errors.INVALID_SETUP_MISSING_ACTOR_REGISTRY_METHOD = "BaseAIRuntimeService actor registry is missing method"
Errors.INVALID_SETUP_NON_BOOLEAN_RUNTIME_FLAG = "BaseAIRuntimeService actor registry returned a non-boolean runtime flag"
Errors.INVALID_SETUP_RUNTIME_ALREADY_STARTED = "BaseAIRuntimeService actor registry must not be started during startup validation"

return table.freeze(Errors)
