--!strict

--[=[
    @class TeardownValidation
    Validates teardown configuration and runtime hook resolution.
    @server
]=]

local Assertions = require(script.Parent.Parent.Internal.Assertions)

local TeardownValidation = {}

--[=[
    Validates the teardown configuration on a service.
    @within TeardownValidation
    @param service any -- Service table that owns the teardown config.
    @param teardown any? -- Teardown configuration or `nil`.
    @error string -- Raised when the teardown config is malformed.
]=]
function TeardownValidation.ValidateConfig(service: any, teardown: any?)
	if teardown == nil then
		return
	end

	assert(type(teardown) == "table", ("%s.Teardown must be a table"):format(service.Name))

	if teardown.Before ~= nil then
		Assertions.AssertCallbackOrMethodName(teardown.Before, ("%s.Teardown.Before"):format(service.Name))
	end

	if teardown.After ~= nil then
		Assertions.AssertCallbackOrMethodName(teardown.After, ("%s.Teardown.After"):format(service.Name))
	end

	if teardown.Fields == nil then
		return
	end

	assert(type(teardown.Fields) == "table", ("%s.Teardown.Fields must be an array table"):format(service.Name))
	for index, spec in ipairs(teardown.Fields) do
		local label = ("%s.Teardown.Fields[%d]"):format(service.Name, index)
		assert(type(spec) == "table", ("%s must be a table"):format(label))
		Assertions.AssertNonEmptyString(spec.Field, label .. ".Field")
		Assertions.AssertOptionalNonEmptyString(spec.Method, label .. ".Method")
	end
end

--[=[
    Validates a teardown hook at runtime.
    @within TeardownValidation
    @param context any -- BaseContext instance that owns the service table.
    @param hook any? -- Hook callback or method name.
    @param label string -- Label used in validation errors.
    @error string -- Raised when the named method does not exist.
]=]
function TeardownValidation.ValidateHookRuntime(context: any, hook: any?, label: string)
	if hook == nil or type(hook) == "function" then
		return
	end

	Assertions.AssertNonEmptyString(hook, label)
	local method = context._service[hook]
	assert(type(method) == "function", ("BaseContext %s method '%s' must exist on service"):format(label, hook))
end

--[=[
    Validates the teardown runtime contract before cleanup executes.
    @within TeardownValidation
    @param context any -- BaseContext instance that owns the service table.
    @param teardown any -- Teardown configuration to validate.
]=]
function TeardownValidation.ValidateRuntime(context: any, teardown: any)
	assert(type(teardown) == "table", "BaseContext Teardown must be a table")
	TeardownValidation.ValidateHookRuntime(context, teardown.Before, "Teardown.Before")
	TeardownValidation.ValidateHookRuntime(context, teardown.After, "Teardown.After")
end

return table.freeze(TeardownValidation)
