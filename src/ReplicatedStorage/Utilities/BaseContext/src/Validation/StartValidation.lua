--!strict

--[=[
    @class StartValidation
    Validates external service/dependency declarations and registry start order.
    @server
]=]

local Assertions = require(script.Parent.Parent.Internal.Assertions)
local Config = require(script.Parent.Parent.Internal.Config)
local ModuleValidation = require(script.Parent.ModuleValidation)

local StartValidation = {}

-- Collects names already present in the registry before start-time validation runs.
local function CollectRegisteredNames(service: any): { [string]: string }
	local seenNames = {}
	local registry = service._registry
	if registry == nil or registry.Modules == nil then
		return seenNames
	end

	for moduleName in pairs(registry.Modules) do
		seenNames[moduleName] = "existing registry module"
	end

	return seenNames
end

--[=[
    Validates external service declarations.
    @within StartValidation
    @param service any -- Service table that owns the config.
    @param externalServices any? -- External service declarations or `nil`.
    @param seenNames { [string]: string } -- Map used to detect duplicate names.
    @error string -- Raised when the declarations are malformed.
]=]
function StartValidation.ValidateExternalServices(service: any, externalServices: any?, seenNames: { [string]: string })
	if externalServices == nil then
		return
	end

	assert(type(externalServices) == "table", ("%s.ExternalServices must be an array table"):format(service.Name))
	for index, spec in ipairs(externalServices) do
		local label = ("%s.ExternalServices[%d]"):format(service.Name, index)
		assert(type(spec) == "table", ("%s must be a table"):format(label))
		Assertions.AssertNonEmptyString(spec.Name, label .. ".Name")
		Assertions.AssertOptionalNonEmptyString(spec.CacheAs, label .. ".CacheAs")
		ModuleValidation.TrackUniqueModuleName(seenNames, spec.Name, label)
	end
end

--[=[
    Validates external dependency declarations.
    @within StartValidation
    @param service any -- Service table that owns the config.
    @param externalDependencies any? -- External dependency declarations or `nil`.
    @param seenNames { [string]: string } -- Map used to detect duplicate names.
    @error string -- Raised when the declarations are malformed.
]=]
function StartValidation.ValidateExternalDependencies(service: any, externalDependencies: any?, seenNames: { [string]: string })
	if externalDependencies == nil then
		return
	end

	assert(type(externalDependencies) == "table", ("%s.ExternalDependencies must be an array table"):format(service.Name))
	for index, spec in ipairs(externalDependencies) do
		local label = ("%s.ExternalDependencies[%d]"):format(service.Name, index)
		assert(type(spec) == "table", ("%s must be a table"):format(label))
		Assertions.AssertNonEmptyString(spec.Name, label .. ".Name")
		Assertions.AssertNonEmptyString(spec.From, label .. ".From")
		Assertions.AssertNonEmptyString(spec.Method, label .. ".Method")
		Assertions.AssertOptionalNonEmptyString(spec.CacheAs, label .. ".CacheAs")
		ModuleValidation.TrackUniqueModuleName(seenNames, spec.Name, label)
	end
end

--[=[
    Validates the configured registry start order.
    @within StartValidation
    @param service any -- Service table that owns the config.
    @param startOrder any? -- Start order array or `nil`.
    @error string -- Raised when the order includes unknown layers.
]=]
function StartValidation.ValidateStartOrder(service: any, startOrder: any?)
	if startOrder == nil then
		return
	end

	assert(type(startOrder) == "table", ("%s.StartOrder must be an array table"):format(service.Name))
	for index, layerName in ipairs(startOrder) do
		assert(Config.KnownLayers[layerName] == true, ("%s.StartOrder[%d] has unknown layer '%s'"):format(service.Name, index, tostring(layerName)))
	end
end

--[=[
    Validates all start-time declarations on the service.
    @within StartValidation
    @param service any -- Service table to validate.
]=]
function StartValidation.Validate(service: any)
	local seenNames = CollectRegisteredNames(service)
	StartValidation.ValidateExternalServices(service, service.ExternalServices, seenNames)
	StartValidation.ValidateExternalDependencies(service, service.ExternalDependencies, seenNames)
	StartValidation.ValidateStartOrder(service, service.StartOrder)
end

return table.freeze(StartValidation)
