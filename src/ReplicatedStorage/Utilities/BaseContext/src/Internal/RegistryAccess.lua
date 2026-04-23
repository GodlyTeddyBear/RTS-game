--!strict

--[=[
    @class RegistryAccess
    Internal access helpers for the registry attached during `KnitInit`.
    @server
]=]

local RegistryAccess = {}

-- Returns the registry reference without validating initialization.
--[=[
    Returns the registry stored on the wrapped service.
    @within RegistryAccess
    @param context any -- BaseContext instance that owns the service table.
    @return any -- Registry reference, if present.
]=]
function RegistryAccess.GetRegistry(context: any): any
	return context._service._registry
end

-- Validates that the registry exists before returning it.
--[=[
    Returns the initialized registry and raises if bootstrap has not run.
    @within RegistryAccess
    @param context any -- BaseContext instance that owns the service table.
    @return any -- Initialized registry reference.
    @error string -- Raised when the registry is missing.
]=]
function RegistryAccess.RequireRegistry(context: any): any
	local registry = context._service._registry
	assert(registry ~= nil, ("%s registry is not initialized"):format(context._service.Name))
	return registry
end

return table.freeze(RegistryAccess)
