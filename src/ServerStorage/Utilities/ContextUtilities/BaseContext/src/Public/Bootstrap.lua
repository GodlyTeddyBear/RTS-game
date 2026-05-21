--!strict

--[=[
    @class Bootstrap
    Boots a wrapped Knit service by validating config, creating the registry,
    and wiring world service, modules, and cached fields.
    @server
]=]

local Registry = require(script.Parent.Parent.Parent.Parent.Registry)
local Validation = require(script.Parent.Parent.Validation)

local BootstrapMethods = {}

--[=[
	Bootstraps the wrapped Knit service table.
	@within Bootstrap
]=]
function BootstrapMethods:KnitInit()
	local service = self._service

	-- Validate the service contract and create the registry first.
	Validation.ValidateServiceConfig(self)
	local registry = Registry.new(self._registryContext)
	service._registry = registry

	-- Register the context-owned world service before any module lookups.
	if service.WorldService then
		self:RegisterWorldService(service.WorldService)
	end

	-- Register modules before caching so downstream fields can resolve cleanly.
	self:RegisterModules(service.Modules)
	self:InitModules(service.Modules)
	self:CacheFields(service.Cache)
end

return BootstrapMethods
