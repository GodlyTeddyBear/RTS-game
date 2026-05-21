--!strict

--[=[
    @class CacheValidation
    Validates cache configuration records before BaseContext writes cached fields.
    @server
]=]

local Assertions = require(script.Parent.Parent.Internal.Assertions)

local CacheValidation = {}

--[=[
    Validates the cache configuration shape on a service.
    @within CacheValidation
    @param service any -- Service table that owns the cache config.
    @param cacheConfig any? -- Cache configuration table or `nil`.
    @error string -- Raised when the cache config is malformed.
]=]
function CacheValidation.Validate(service: any, cacheConfig: any?)
	if cacheConfig == nil then
		return
	end

	assert(type(cacheConfig) == "table", ("%s.Cache must be a table"):format(service.Name))
	for registryName, cacheSpec in pairs(cacheConfig) do
		if type(cacheSpec) == "string" then
			Assertions.AssertNonEmptyString(registryName, "Cache registry name")
			Assertions.AssertNonEmptyString(cacheSpec, ("Cache.%s target field"):format(tostring(registryName)))
		else
			local label = ("Cache.%s"):format(tostring(registryName))
			assert(type(cacheSpec) == "table", ("%s must be a string or table"):format(label))
			Assertions.AssertNonEmptyString(cacheSpec.Field, label .. ".Field")
			Assertions.AssertNonEmptyString(cacheSpec.From, label .. ".From")
			Assertions.AssertOptionalNonEmptyString(cacheSpec.Method, label .. ".Method")
			if cacheSpec.Result ~= nil then
				assert(type(cacheSpec.Result) == "boolean", ("%s.Result must be a boolean"):format(label))
			end
		end
	end
end

return table.freeze(CacheValidation)
