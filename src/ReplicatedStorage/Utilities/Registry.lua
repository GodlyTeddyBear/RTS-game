--!strict
--!optimize 2
--!native

-- Represents a module with optional lifecycle methods.
export type Module = {
	Setup: ((self: Module) -> ())?,
	Init: ((self: Module, registry: Registry, name: string) -> ())?,
	Start: ((self: Module) -> ())?,
	Destroy: ((self: Module) -> ())?,
}

-- Defines the execution context for the registry.
export type RegistryContext = "Server" | "Client" | "Shared"

-- Main Registry class for managing module lifecycle.
export type Registry = {
	Context: RegistryContext,
	Modules: { [string]: Module },
	ModulesByPath: { [string]: Module },
	Categories: { [Module]: string },

	Register: (self: Registry, name: string | Instance, module: ModuleScript | Module, category: string?) -> (),
	Get: (self: Registry, nameOrInstance: string | Instance) -> Module,
	InitAll: (self: Registry) -> (),
	StartAll: (self: Registry) -> (),
	StartOrdered: (self: Registry, startOrder: {string}) -> (),
	StartModule: (self: Registry, module: Module) -> (),

	_ResolveName: (self: Registry, name: string | Instance) -> string,
	_ResolvePath: (self: Registry, name: string | Instance, module: ModuleScript | Module) -> string?,
	_GetByInstance: (self: Registry, instance: Instance) -> Module,
}

-- Registry class table with metatable for instance methods
local Registry = {}
Registry.__index = Registry

-- Expose Registry globally for cross-module access
_G.Registry = Registry

-- Creates a new Registry instance for a specific context.
function Registry.new(Context: RegistryContext): Registry
	local self = setmetatable({}, Registry) :: any
	self.Modules = {}
	self.ModulesByPath = {}
	self.Categories = setmetatable({}, { __mode = "k" })
	self.Context = Context
	return self :: Registry
end

-- Registers a module by name with optional category for organization.
function Registry:Register(name: string | Instance, module: ModuleScript | Module, category: string?)
	assert(module ~= nil, "[Registry] module cannot be nil")

	local moduleName = self:_ResolveName(name)
	local modulePath = self:_ResolvePath(name, module)

	if typeof(module) == "Instance" and module:IsA("ModuleScript") then
		module = require(module) :: Module
	end

	assert(not self.Modules[moduleName], "[Registry] duplicate module registration: " .. moduleName)

	-- Store module
	self.Modules[moduleName] = module :: Module

	-- Store path mapping if available
	if modulePath then
		self.ModulesByPath[modulePath] = module :: Module
	end

	-- Store category if provided
	if category then
		self.Categories[module :: Module] = category
	end
end

-- Retrieves a registered module by name or instance.
function Registry:Get(nameOrInstance: string | Instance): Module
	if typeof(nameOrInstance) == "Instance" then
		return self:_GetByInstance(nameOrInstance)
	end

	local module = self.Modules[nameOrInstance]
	assert(module ~= nil, "[Registry] module not found: " .. nameOrInstance)
	return module
end

-- Calls Init method on all registered modules, passing registry instance and module name.
function Registry:InitAll()
	for name, module in pairs(self.Modules) do
		if type(module) == "function" then
			continue
		end

		if module.Init and type(module.Init) == "function" then
			module:Init(self, name)
		end
	end
end

-- Starts a single module by calling its Start method if it exists.
function Registry:StartModule(module: Module, name: string)
	if type(module) == "function" then
		return
	end

	if module.Start then
		module:Start(self, name)
	end
end

-- Starts all registered modules in arbitrary order.
function Registry:StartAll()
	for name, module in pairs(self.Modules) do
		self:StartModule(module, name)
	end
end

-- Starts modules in a specific category order, processing all modules in each category before moving to the next.
function Registry:StartOrdered(startOrder: {string})
	for _, category in ipairs(startOrder) do
		for name, module in pairs(self.Modules) do
			if self.Categories[module] == category then
				self:StartModule(module, name)
			end
		end
	end
end

-- Resolves a module name from a string or Instance.
function Registry:_ResolveName(name: string | Instance): string
	if typeof(name) == "Instance" then
		return name.Name
	end
	assert(type(name) == "string" and name ~= "", "[Registry] name must be non-empty string or Instance")
	return name
end

-- Resolves a module path from a name parameter and module instance.
function Registry:_ResolvePath(name: string | Instance, module: ModuleScript | Module): string?
	if typeof(name) == "Instance" then
		return name:GetFullName()
	end
	if typeof(module) == "Instance" and module:IsA("ModuleScript") then
		return module:GetFullName()
	end
	return nil
end

-- Gets a module by Instance with path and name fallback.
function Registry:_GetByInstance(instance: Instance): Module
	local fullPath = instance:GetFullName()

	-- Try path-based lookup first
	local module = self.ModulesByPath[fullPath]
	if module then
		return module
	end

	-- Fall back to name-based lookup
	module = self.Modules[instance.Name]
	assert(module ~= nil, "[Registry] module not found: " .. instance.Name)
	return module
end

return Registry