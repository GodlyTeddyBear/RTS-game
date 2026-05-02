--!strict

--[=[
    @class AIRuntimeValidation
    Validates optional BaseContext AI runtime startup configuration and runtime bindings.
    @server
]=]

local AIRuntimeValidationPolicy = require(script.Parent.Policies.AIRuntimeValidationPolicy)

local AIRuntimeValidation = {}

--[=[
    Validates the optional AI runtime config on a service table.
    @within AIRuntimeValidation
    @param service any -- Service table that owns the config.
    @param aiRuntimeContext any? -- Optional AI runtime config.
]=]
function AIRuntimeValidation.ValidateConfig(service: any, aiRuntimeContext: any?)
	AIRuntimeValidationPolicy.AssertConfig(service, aiRuntimeContext)
end

--[=[
    Validates the resolved AI runtime and actor registry pair after startup registration.
    @within AIRuntimeValidation
    @param context any -- BaseContext instance that owns the service table.
]=]
function AIRuntimeValidation.ValidateRuntime(context: any)
	AIRuntimeValidationPolicy.ValidateRuntime(context)
end

return table.freeze(AIRuntimeValidation)
