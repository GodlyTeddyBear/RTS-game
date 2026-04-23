--!strict

local RegistryAccess = require(script.Parent.RegistryAccess)

--[=[
    @class ModuleFactory
    Internal module construction helpers for BaseContext registry registration.
    @server
]=]

local ModuleFactory = {}

-- Builds a module instance from an explicit instance, factory, or module source.
--[=[
    Creates a module instance from a BaseContext module spec.
    @within ModuleFactory
    @param context any -- BaseContext instance used when invoking factories.
    @param spec any -- Module specification to resolve.
    @return any -- Resolved module instance.
    @error string -- Raised when the spec does not provide a usable source.
]=]
function ModuleFactory.Create(context: any, spec: any): any
	if spec.Instance ~= nil then
		return spec.Instance
	end

	if spec.Factory ~= nil then
		return spec.Factory(context._service, context)
	end

	assert(spec.Module ~= nil, ("BaseContext module spec '%s' requires Module, Factory, or Instance"):format(spec.Name))

	if type(spec.Module) == "table" and type(spec.Module.new) == "function" then
		return spec.Module.new(table.unpack(spec.Args or {}))
	end

	return spec.Module
end

-- Prevents duplicate module initialization and calls `Init` when the module exposes one.
--[=[
    Initializes a registered module once per context.
    @within ModuleFactory
    @param context any -- BaseContext instance that owns the registry.
    @param moduleName string -- Registry name of the module to initialize.
]=]
function ModuleFactory.InitRegisteredModule(context: any, moduleName: string)
	if context._initializedModules[moduleName] then
		return
	end

	local registry = RegistryAccess.RequireRegistry(context)
	local module = registry:Get(moduleName)
	if type(module) == "function" then
		context._initializedModules[moduleName] = true
		return
	end

	if module.Init and type(module.Init) == "function" then
		module:Init(registry, moduleName)
	end

	context._initializedModules[moduleName] = true
end

return table.freeze(ModuleFactory)
