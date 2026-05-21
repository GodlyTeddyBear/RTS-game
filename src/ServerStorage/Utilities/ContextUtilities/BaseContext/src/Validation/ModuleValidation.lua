--!strict

--[=[
    @class ModuleValidation
    Validates BaseContext module specs, layer names, and registry uniqueness.
    @server
]=]

local Assertions = require(script.Parent.Parent.Internal.Assertions)
local Config = require(script.Parent.Parent.Internal.Config)

local ModuleValidation = {}

-- Counts which module source fields are present on a spec.
local function CountModuleSources(spec: any): number
	local sourceCount = 0
	if spec.Instance ~= nil then
		sourceCount += 1
	end
	if spec.Factory ~= nil then
		sourceCount += 1
	end
	if spec.Module ~= nil then
		sourceCount += 1
	end
	return sourceCount
end

--[=[
    Records a module name in the uniqueness map and rejects duplicates.
    @within ModuleValidation
    @param seenNames { [string]: string } -- Map of module names already seen.
    @param moduleName string -- Module name to track.
    @param label string -- Label used in duplicate-name errors.
    @error string -- Raised when the name has already been registered.
]=]
function ModuleValidation.TrackUniqueModuleName(seenNames: { [string]: string }, moduleName: string, label: string)
	local previousLabel = seenNames[moduleName]
	assert(previousLabel == nil, ("Duplicate BaseContext module name '%s' in %s; already declared in %s"):format(moduleName, label, tostring(previousLabel)))
	seenNames[moduleName] = label
end

--[=[
    Validates a single module spec.
    @within ModuleValidation
    @param spec any -- Module specification to validate.
    @param label string -- Label used in validation errors.
    @error string -- Raised when the module spec is malformed.
]=]
function ModuleValidation.ValidateModuleSpec(spec: any, label: string)
	assert(type(spec) == "table", ("%s must be a table"):format(label))
	Assertions.AssertNonEmptyString(spec.Name, label .. ".Name")

	local sourceCount = CountModuleSources(spec)
	assert(sourceCount == 1, ("%s must define exactly one of Instance, Factory, or Module"):format(label))

	if spec.Factory ~= nil then
		assert(type(spec.Factory) == "function", ("%s.Factory must be a function"):format(label))
	end

	Assertions.AssertOptionalNonEmptyString(spec.Category, label .. ".Category")
	Assertions.AssertOptionalNonEmptyString(spec.CacheAs, label .. ".CacheAs")

	if spec.Args ~= nil then
		assert(type(spec.Args) == "table", ("%s.Args must be a table"):format(label))
	end
end

--[=[
    Validates all service-owned module declarations and returns known names.
    @within ModuleValidation
    @param service any -- Service table that owns the module config.
    @return { [string]: string } -- Map of known module names to their source labels.
    @error string -- Raised when the module configuration is malformed.
]=]
function ModuleValidation.ValidateServiceModules(service: any): { [string]: string }
	local seenNames = {}

	if service.WorldService ~= nil then
		seenNames.World = "implicit World from WorldService"
		ModuleValidation.ValidateModuleSpec(service.WorldService, "WorldService")
		ModuleValidation.TrackUniqueModuleName(seenNames, service.WorldService.Name, "WorldService")
	end

	if service.Modules == nil then
		return seenNames
	end

	assert(type(service.Modules) == "table", ("%s.Modules must be a table"):format(service.Name))
	for layerName, moduleSpecs in pairs(service.Modules) do
		assert(Config.KnownLayers[layerName] == true, ("%s.Modules has unknown layer '%s'"):format(service.Name, tostring(layerName)))
		assert(type(moduleSpecs) == "table", ("%s.Modules.%s must be an array table"):format(service.Name, tostring(layerName)))

		for index, spec in ipairs(moduleSpecs) do
			local label = ("%s.Modules.%s[%d]"):format(service.Name, tostring(layerName), index)
			ModuleValidation.ValidateModuleSpec(spec, label)
			ModuleValidation.TrackUniqueModuleName(seenNames, spec.Name, label)
		end
	end

	return seenNames
end

return table.freeze(ModuleValidation)
