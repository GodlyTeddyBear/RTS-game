--!strict

--[=[
    @class LifecycleValidation
    Validates profile lifecycle configuration and runtime handler availability.
    @server
]=]

local Assertions = require(script.Parent.Parent.Internal.Assertions)

local LifecycleValidation = {}

--[=[
    Validates the profile lifecycle configuration on a service.
    @within LifecycleValidation
    @param service any -- Service table that owns the profile lifecycle config.
    @param profileLifecycle any? -- Profile lifecycle configuration or `nil`.
    @error string -- Raised when the lifecycle config is malformed.
]=]
function LifecycleValidation.ValidateConfig(service: any, profileLifecycle: any?)
	if profileLifecycle == nil then
		return
	end

	assert(type(profileLifecycle) == "table", ("%s.ProfileLifecycle must be a table"):format(service.Name))
	Assertions.AssertNonEmptyString(profileLifecycle.LoaderName, ("%s.ProfileLifecycle.LoaderName"):format(service.Name))
	Assertions.AssertCallbackOrMethodName(profileLifecycle.OnLoaded, ("%s.ProfileLifecycle.OnLoaded"):format(service.Name))

	if profileLifecycle.OnSaving ~= nil then
		Assertions.AssertCallbackOrMethodName(profileLifecycle.OnSaving, ("%s.ProfileLifecycle.OnSaving"):format(service.Name))
	end

	if profileLifecycle.OnRemoving ~= nil then
		Assertions.AssertCallbackOrMethodName(profileLifecycle.OnRemoving, ("%s.ProfileLifecycle.OnRemoving"):format(service.Name))
	end

	if profileLifecycle.Backfill ~= nil then
		assert(type(profileLifecycle.Backfill) == "boolean", ("%s.ProfileLifecycle.Backfill must be a boolean"):format(service.Name))
	end
end

--[=[
    Validates a lifecycle callback or method name against the service table.
    @within LifecycleValidation
    @param context any -- BaseContext instance that owns the service table.
    @param callbackOrMethodName any? -- Callback or method-name override.
    @param label string -- Label used in validation errors.
    @error string -- Raised when the named method is missing.
]=]
function LifecycleValidation.ValidateHandlerExists(context: any, callbackOrMethodName: any?, label: string)
	if callbackOrMethodName == nil then
		return
	end

	Assertions.AssertCallbackOrMethodName(callbackOrMethodName, label)
	if type(callbackOrMethodName) ~= "string" then
		return
	end

	local method = context._service[callbackOrMethodName]
	assert(type(method) == "function", ("BaseContext %s method '%s' must exist on service"):format(label, callbackOrMethodName))
end

--[=[
    Validates that all profile lifecycle runtime handlers can be resolved.
    @within LifecycleValidation
    @param context any -- BaseContext instance that owns the service table.
]=]
function LifecycleValidation.ValidateRuntimeMethods(context: any)
	local profileLifecycle = context._service.ProfileLifecycle
	assert(type(profileLifecycle) == "table", "BaseContext ProfileLifecycle must be configured")

	LifecycleValidation.ValidateHandlerExists(context, profileLifecycle.OnLoaded, "ProfileLifecycle.OnLoaded")
	LifecycleValidation.ValidateHandlerExists(context, profileLifecycle.OnSaving, "ProfileLifecycle.OnSaving")
	LifecycleValidation.ValidateHandlerExists(context, profileLifecycle.OnRemoving, "ProfileLifecycle.OnRemoving")
end

return table.freeze(LifecycleValidation)
