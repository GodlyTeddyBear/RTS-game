--!strict

local Assertions = require(script.Parent.Assertions)

--[=[
    @class MethodResolver
    Internal helpers that normalize method names and resolve cached service methods.
    @server
]=]

local MethodResolver = {}

-- Falls back to the provided default name and validates any explicit override.
--[=[
    Resolves an optional method name against a default.
    @within MethodResolver
    @param methodName string? -- Optional override from configuration.
    @param defaultMethodName string -- Default method name to use when no override is present.
    @param label string -- Label used in validation errors.
    @return string -- Resolved method name.
    @error string -- Raised when the override is present but invalid.
]=]
function MethodResolver.ResolveMethodName(methodName: string?, defaultMethodName: string, label: string): string
	if methodName == nil then
		return defaultMethodName
	end

	Assertions.AssertNonEmptyString(methodName, label)
	return methodName
end

-- Resolves a service field and the named method expected to exist on that field.
--[=[
    Resolves a target service field and validates a callable method on it.
    @within MethodResolver
    @param context any -- BaseContext instance that owns the service table.
    @param targetField string -- Service field that contains the target object.
    @param methodName string -- Method name to resolve on the target object.
    @param label string -- Label used in validation errors.
    @return any -- Target object retrieved from the service table.
    @return any -- Resolved method function.
    @error string -- Raised when the field or method is missing.
]=]
function MethodResolver.ResolveTargetMethod(context: any, targetField: string, methodName: string, label: string): (any, any)
	Assertions.AssertNonEmptyString(targetField, label .. " targetField")
	Assertions.AssertNonEmptyString(methodName, label .. " methodName")

	local target = context._service[targetField]
	assert(target ~= nil, ("BaseContext %s target '%s' was not found"):format(label, targetField))

	local method = target[methodName]
	assert(
		type(method) == "function",
		("BaseContext %s method '%s.%s' must be a function"):format(label, targetField, methodName)
	)

	return target, method
end

return table.freeze(MethodResolver)
