--!strict

--[=[
    @class Modules
    Registers configured modules into the registry and initializes them in order.
    @server
]=]

local Config = require(script.Parent.Parent.Internal.Config)
local ModuleFactory = require(script.Parent.Parent.Internal.ModuleFactory)
local RegistryAccess = require(script.Parent.Parent.Internal.RegistryAccess)

local ModuleMethods = {}

-- Registers the context-owned world service before any other module resolution.
--[=[
    Registers the world service and its world handle.
    @within Modules
    @param spec any -- World service specification.
]=]
function ModuleMethods:RegisterWorldService(spec: any)
	local service = self._service
	local registry = RegistryAccess.RequireRegistry(self)
	local worldService = ModuleFactory.Create(self, spec)

	registry:Register(spec.Name, worldService, spec.Category or "Infrastructure")
	ModuleFactory.InitRegisteredModule(self, spec.Name)
	registry:Register("World", worldService:GetWorld())

	if spec.CacheAs then
		service[spec.CacheAs] = worldService
	end
end

-- Registers all modules across the known layer order.
--[=[
    Registers every configured module layer.
    @within Modules
    @param modules any? -- Layered module configuration.
]=]
function ModuleMethods:RegisterModules(modules: any?)
	if modules == nil then
		return
	end

	for _, layerName in ipairs(Config.LayerOrder) do
		self:RegisterLayerModules(layerName, modules[layerName])
	end
end

-- Registers one module layer into the registry.
--[=[
    Registers a single module layer.
    @within Modules
    @param layerName string -- Module layer name.
    @param moduleSpecs { any }? -- Module specs for the layer.
]=]
function ModuleMethods:RegisterLayerModules(layerName: string, moduleSpecs: { any }?)
	if moduleSpecs == nil then
		return
	end

	local service = self._service
	local registry = RegistryAccess.RequireRegistry(self)
	for _, spec in ipairs(moduleSpecs) do
		local moduleInstance = ModuleFactory.Create(self, spec)
		registry:Register(spec.Name, moduleInstance, spec.Category or layerName)

		if spec.CacheAs then
			service[spec.CacheAs] = moduleInstance
		end
	end
end

-- Initializes registered modules after registration is complete.
--[=[
    Initializes every registered module exactly once.
    @within Modules
    @param modules any? -- Layered module configuration.
]=]
function ModuleMethods:InitModules(modules: any?)
	if modules == nil then
		return
	end

	for _, layerName in ipairs(Config.LayerOrder) do
		local moduleSpecs = modules[layerName]
		if moduleSpecs == nil then
			continue
		end

		for _, spec in ipairs(moduleSpecs) do
			ModuleFactory.InitRegisteredModule(self, spec.Name)
		end
	end
end

return ModuleMethods
