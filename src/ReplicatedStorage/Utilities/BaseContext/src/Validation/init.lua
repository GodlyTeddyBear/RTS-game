--!strict

--[=[
    @class Validation
    Validates BaseContext service configuration and runtime lifecycle contracts.
    @server
]=]

local Assertions = require(script.Parent.Internal.Assertions)
local AIRuntimeValidation = require(script.AIRuntimeValidation)
local CacheValidation = require(script.CacheValidation)
local LifecycleValidation = require(script.LifecycleValidation)
local ModuleValidation = require(script.ModuleValidation)
local StartValidation = require(script.StartValidation)
local TeardownValidation = require(script.TeardownValidation)

local Validation = {}

--[=[
    Validates the bootstrap-time service configuration.
    @within Validation
    @param context any -- BaseContext instance to validate.
]=]
function Validation.ValidateServiceConfig(context: any)
	local service = context._service
	assert(type(service) == "table", "BaseContext service must be a table")
	Assertions.AssertNonEmptyString(service.Name, "BaseContext service.Name")

	ModuleValidation.ValidateServiceModules(service)
	CacheValidation.Validate(service, service.Cache)
	AIRuntimeValidation.ValidateConfig(service, service.AIRuntimeContext)
	LifecycleValidation.ValidateConfig(service, service.ProfileLifecycle)
	TeardownValidation.ValidateConfig(service, service.Teardown)
end

--[=[
    Validates the start-time service configuration.
    @within Validation
    @param context any -- BaseContext instance to validate.
]=]
function Validation.ValidateStartConfig(context: any)
	local service = context._service
	assert(type(service) == "table", "BaseContext service must be a table")
	Assertions.AssertNonEmptyString(service.Name, "BaseContext service.Name")

	StartValidation.Validate(service)
	AIRuntimeValidation.ValidateConfig(service, service.AIRuntimeContext)
	LifecycleValidation.ValidateConfig(service, service.ProfileLifecycle)
	TeardownValidation.ValidateConfig(service, service.Teardown)
end

--[=[
    Validates the optional AI runtime pair after BaseContext start registration completes.
    @within Validation
    @param context any -- BaseContext instance to validate.
]=]
function Validation.ValidateAIRuntimeRuntime(context: any)
	AIRuntimeValidation.ValidateRuntime(context)
end

--[=[
    Validates that profile lifecycle handlers exist on the service.
    @within Validation
    @param context any -- BaseContext instance to validate.
]=]
function Validation.ValidateProfileLifecycleMethods(context: any)
	LifecycleValidation.ValidateRuntimeMethods(context)
end

--[=[
    Validates teardown runtime state before cleanup executes.
    @within Validation
    @param context any -- BaseContext instance to validate.
    @param teardown any -- Teardown configuration to validate.
]=]
function Validation.ValidateTeardownRuntime(context: any, teardown: any)
	TeardownValidation.ValidateRuntime(context, teardown)
end

return table.freeze(Validation)
