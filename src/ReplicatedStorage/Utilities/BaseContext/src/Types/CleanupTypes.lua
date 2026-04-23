--!strict

--[=[
    @class CleanupTypes
    Shared teardown specification types for BaseContext cleanup configuration.
    @server
]=]

local CleanupTypes = {}

--[=[
    @interface TTeardownFieldSpec
    @within CleanupTypes
    .Field string -- Service field to clean up.
    .Method string? -- Optional cleanup method override.
]=]
export type TTeardownFieldSpec = {
	Field: string,
	Method: string?,
}

--[=[
    @interface TTeardownSpec
    @within CleanupTypes
    .Before (string | (() -> ()))? -- Optional hook or method name to run before cleanup.
    .After (string | (() -> ()))? -- Optional hook or method name to run after cleanup.
    .Fields { TTeardownFieldSpec }? -- Optional field cleanup declarations.
]=]
export type TTeardownSpec = {
	Before: (string | (() -> ()))?,
	After: (string | (() -> ()))?,
	Fields: { TTeardownFieldSpec }?,
}

return table.freeze(CleanupTypes)
