--!strict

--[=[
    @class Cache
    Populates cached service fields from registry values or derived method results.
    @server
]=]

local Assertions = require(script.Parent.Parent.Internal.Assertions)
local RegistryAccess = require(script.Parent.Parent.Internal.RegistryAccess)
local ResultAccess = require(script.Parent.Parent.Internal.ResultAccess)

local CacheMethods = {}

-- Resolves each cache entry and writes the value onto the service table.
--[=[
    Applies a cache configuration to the wrapped service.
    @within Cache
    @param cacheConfig any? -- Cache configuration table or `nil`.
]=]
function CacheMethods:CacheFields(cacheConfig: any?)
	if cacheConfig == nil then
		return
	end

	for cacheName, cacheSpec in pairs(cacheConfig) do
		if type(cacheSpec) == "string" then
			self:CacheRegistryValue(cacheName, cacheSpec)
		else
			self:CacheMethodResult(cacheSpec)
		end
	end
end

-- Caches a direct registry value under a service field.
--[=[
    Copies a registry value to a named service field.
    @within Cache
    @param registryName string -- Registry entry to read.
    @param fieldName string -- Service field to assign.
    @error string -- Raised when the registry lookup fails.
]=]
function CacheMethods:CacheRegistryValue(registryName: string, fieldName: string)
	Assertions.AssertNonEmptyString(registryName, "BaseContext cache registry name")
	Assertions.AssertNonEmptyString(fieldName, ("BaseContext cache field for '%s'"):format(registryName))
	self._service[fieldName] = RegistryAccess.RequireRegistry(self):Get(registryName)
end

-- Calls a registry module method and stores either the raw or unwrapped result.
--[=[
    Resolves a cached value from a registry module method.
    @within Cache
    @param cacheSpec any -- Cache specification record.
    @error string -- Raised when the source or method lookup fails.
]=]
function CacheMethods:CacheMethodResult(cacheSpec: any)
	Assertions.AssertNonEmptyString(cacheSpec.Field, "BaseContext derived cache Field")
	Assertions.AssertNonEmptyString(cacheSpec.From, ("BaseContext cache for field '%s' From"):format(cacheSpec.Field))

	-- Resolve the source module first so downstream method calls stay local.
	local source = RegistryAccess.RequireRegistry(self):Get(cacheSpec.From)
	if cacheSpec.Method == nil then
		self._service[cacheSpec.Field] = source
		return
	end

	Assertions.AssertNonEmptyString(cacheSpec.Method, ("BaseContext cache for field '%s' Method"):format(cacheSpec.Field))
	local method = source[cacheSpec.Method]
	assert(type(method) == "function", ("BaseContext cache source '%s' method '%s' must be a function"):format(cacheSpec.From, cacheSpec.Method))

	-- Unwrap Result values when the cache expects a concrete payload.
	local value = method(source)
	if cacheSpec.Result ~= false then
		value = ResultAccess.RequireValue(value, ("%s:%s"):format(cacheSpec.From, cacheSpec.Method))
	end

	self._service[cacheSpec.Field] = value
end

return CacheMethods
