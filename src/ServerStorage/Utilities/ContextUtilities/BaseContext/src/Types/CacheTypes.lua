--!strict

--[=[
    @class CacheTypes
    Shared cache specification types for BaseContext configuration.
    @server
]=]

local CacheTypes = {}

--[=[
    @interface TCacheMethodSpec
    @within CacheTypes
    .Field string -- Service field to populate.
    .From string -- Registry module to read from.
    .Method string? -- Optional method name used to derive the value.
    .Result boolean? -- Whether to unwrap the return value as a Result.
]=]
export type TCacheMethodSpec = {
	Field: string,
	From: string,
	Method: string?,
	Result: boolean?,
}

--[=[
    @type TCacheConfig
    @within CacheTypes
    Map of registry names to cached service fields or derived cache specs.
]=]
export type TCacheConfig = {
	[string]: string | TCacheMethodSpec,
}

return table.freeze(CacheTypes)
