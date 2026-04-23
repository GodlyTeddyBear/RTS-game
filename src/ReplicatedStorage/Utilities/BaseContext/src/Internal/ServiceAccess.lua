--!strict

local Assertions = require(script.Parent.Assertions)

--[=[
    @class ServiceAccess
    Internal helpers that validate service fields, methods, and lifecycle callbacks.
    @server
]=]

local ServiceAccess = {}

-- Returns a required field from the service table.
--[=[
    Returns a required service field.
    @within ServiceAccess
    @param context any -- BaseContext instance that owns the service table.
    @param fieldName string -- Service field name to resolve.
    @return any -- Field value.
    @error string -- Raised when the field is missing.
]=]
function ServiceAccess.RequireField(context: any, fieldName: string): any
	Assertions.AssertNonEmptyString(fieldName, "BaseContext service fieldName")

	local value = context._service[fieldName]
	assert(value ~= nil, ("BaseContext service field '%s' is missing"):format(fieldName))
	return value
end

-- Returns a required callable method from a target object.
--[=[
    Returns a required method from a target object.
    @within ServiceAccess
    @param target any -- Object that should expose the method.
    @param methodName string -- Method name to resolve.
    @param label string -- Label used in validation errors.
    @return any -- Resolved method function.
    @error string -- Raised when the method is missing or not callable.
]=]
function ServiceAccess.RequireMethod(target: any, methodName: string, label: string): any
	Assertions.AssertNonEmptyString(methodName, label .. " methodName")

	local method = target[methodName]
	assert(type(method) == "function", ("%s method '%s' must be a function"):format(label, methodName))
	return method
end

-- Calls either a callback or a service method name for lifecycle hooks.
--[=[
    Invokes a service hook as either a function or a named service method.
    @within ServiceAccess
    @param context any -- BaseContext instance that owns the service table.
    @param hook any? -- Callback or method name to invoke.
    @param label string -- Label used in validation errors.
    @error string -- Raised when the named method does not exist.
]=]
function ServiceAccess.CallServiceHook(context: any, hook: any?, label: string)
	if hook == nil then
		return
	end

	if type(hook) == "function" then
		hook()
		return
	end

	Assertions.AssertNonEmptyString(hook, label)
	local method = context._service[hook]
	assert(type(method) == "function", ("BaseContext %s method '%s' must exist on service"):format(label, hook))
	method(context._service)
end

-- Calls a profile lifecycle handler using the same callback-or-method contract.
--[=[
    Invokes a profile lifecycle handler as a callback or named service method.
    @within ServiceAccess
    @param context any -- BaseContext instance that owns the service table.
    @param callbackOrMethodName any -- Callback or method name to invoke.
    @param player Player -- Player being processed by the lifecycle handler.
    @error string -- Raised when the named method does not exist.
]=]
function ServiceAccess.CallProfileHandler(context: any, callbackOrMethodName: any, player: Player)
	if type(callbackOrMethodName) == "function" then
		callbackOrMethodName(player)
		return
	end

	local method = context._service[callbackOrMethodName]
	assert(type(method) == "function", ("BaseContext profile lifecycle method '%s' must be a function"):format(callbackOrMethodName))
	method(context._service, player)
end

return table.freeze(ServiceAccess)
