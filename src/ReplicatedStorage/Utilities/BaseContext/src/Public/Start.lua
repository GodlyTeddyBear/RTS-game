--!strict

--[=[
    @class Start
    Registers external services and dependencies, then starts ordered modules.
    @server
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)

local Config = require(script.Parent.Parent.Internal.Config)
local RegistryAccess = require(script.Parent.Parent.Internal.RegistryAccess)
local ResultAccess = require(script.Parent.Parent.Internal.ResultAccess)
local Validation = require(script.Parent.Parent.Validation)

local StartMethods = {}

--[=[
	Registers external dependencies and starts registry modules.
	@within Start
]=]
function StartMethods:KnitStart()
	-- Validate the start contract before touching the registry or external services.
	Validation.ValidateStartConfig(self)
	RegistryAccess.RequireRegistry(self)

	-- Register all external services before dependency resolution begins.
	self:RegisterExternalServices()
	self:RegisterExternalDependencies()

	-- Start modules after all registry entries are available.
	self:StartRegisteredModules()
end

-- Registers all configured external Knit services.
--[=[
    Registers every configured external service.
    @within Start
]=]
function StartMethods:RegisterExternalServices()
	local externalServices = self._service.ExternalServices
	if externalServices == nil then
		return
	end

	for _, spec in ipairs(externalServices) do
		self:RegisterExternalService(spec)
	end
end

-- Registers all configured external dependency values.
--[=[
    Registers every configured external dependency.
    @within Start
]=]
function StartMethods:RegisterExternalDependencies()
	local externalDependencies = self._service.ExternalDependencies
	if externalDependencies == nil then
		return
	end

	for _, spec in ipairs(externalDependencies) do
		self:RegisterExternalDependency(spec)
	end
end

-- Registers one external Knit service and optionally caches it.
--[=[
    Registers a single external Knit service.
    @within Start
    @param spec any -- External service specification.
]=]
function StartMethods:RegisterExternalService(spec: any)
	local service = self._service
	local registry = RegistryAccess.RequireRegistry(self)
	local externalService = Knit.GetService(spec.Name)

	registry:Register(spec.Name, externalService)

	if spec.CacheAs then
		service[spec.CacheAs] = externalService
	end
end

-- Resolves and registers a value from another context's startup method.
--[=[
    Registers a single external dependency value.
    @within Start
    @param spec any -- External dependency specification.
    @error string -- Raised when the dependency method does not return a Result.
]=]
function StartMethods:RegisterExternalDependency(spec: any)
	local service = self._service
	local registry = RegistryAccess.RequireRegistry(self)
	-- Resolve the source module first so the dependency method can be called directly.
	local source = registry:Get(spec.From)
	local method = source[spec.Method]
	assert(type(method) == "function", ("BaseContext external dependency '%s' source '%s' method '%s' must be a function"):format(spec.Name, spec.From, spec.Method))

	-- Unwrap the dependency result before registering the final value.
	local result = method(source)
	local value = ResultAccess.RequireValue(result, ("%s:%s"):format(spec.From, spec.Method))

	registry:Register(spec.Name, value)

	if spec.CacheAs then
		service[spec.CacheAs] = value
	end
end

-- Starts registered modules in the configured order.
--[=[
    Starts registered modules in registry order.
    @within Start
]=]
function StartMethods:StartRegisteredModules()
	local registry = RegistryAccess.RequireRegistry(self)
	registry:StartOrdered(self._service.StartOrder or Config.DefaultStartOrder)
end

return StartMethods
