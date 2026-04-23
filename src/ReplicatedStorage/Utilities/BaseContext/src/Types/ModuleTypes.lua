--!strict

--[=[
    @class ModuleTypes
    Shared module registration types for BaseContext layers and world services.
    @server
]=]

local ModuleTypes = {}

--[=[
    @interface TModuleSpec
    @within ModuleTypes
    .Name string -- Registry name for the module.
    .Module any? -- Module source when registering a direct module.
    .Instance any? -- Prebuilt instance when registering an existing object.
    .Factory ((service: any, baseContext: any) -> any)? -- Factory used to build the module.
    .Category string? -- Registry category override.
    .CacheAs string? -- Optional service field used to cache the module instance.
    .Args { any }? -- Constructor arguments for module tables with `new`.
]=]
export type TModuleSpec = {
	Name: string,
	Module: any?,
	Instance: any?,
	Factory: ((service: any, baseContext: any) -> any)?,
	Category: string?,
	CacheAs: string?,
	Args: { any }?,
}

--[=[
    @type TWorldServiceSpec
    @within ModuleTypes
    Alias for `TModuleSpec` used by the world service registration path.
]=]
export type TWorldServiceSpec = TModuleSpec

--[=[
    @interface TModuleLayers
    @within ModuleTypes
    .Infrastructure { TModuleSpec }? -- Infrastructure layer modules.
    .Domain { TModuleSpec }? -- Domain layer modules.
    .Application { TModuleSpec }? -- Application layer modules.
]=]
export type TModuleLayers = {
	Infrastructure: { TModuleSpec }?,
	Domain: { TModuleSpec }?,
	Application: { TModuleSpec }?,
	[string]: { TModuleSpec }?,
}

return table.freeze(ModuleTypes)
