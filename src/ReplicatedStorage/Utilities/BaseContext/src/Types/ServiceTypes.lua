--!strict

--[=[
    @class ServiceTypes
    Shared service table and external dependency types for BaseContext.
    @server
]=]

local ModuleTypes = require(script.Parent.ModuleTypes)
local CacheTypes = require(script.Parent.CacheTypes)
local CleanupTypes = require(script.Parent.CleanupTypes)
local LifecycleTypes = require(script.Parent.LifecycleTypes)

local ServiceTypes = {}

--[=[
    @type TModuleLayers
    @within ServiceTypes
    Alias for `ModuleTypes.TModuleLayers`.
]=]
export type TModuleLayers = ModuleTypes.TModuleLayers

--[=[
    @type TWorldServiceSpec
    @within ServiceTypes
    Alias for `ModuleTypes.TWorldServiceSpec`.
]=]
export type TWorldServiceSpec = ModuleTypes.TWorldServiceSpec

--[=[
    @type TCacheConfig
    @within ServiceTypes
    Alias for `CacheTypes.TCacheConfig`.
]=]
export type TCacheConfig = CacheTypes.TCacheConfig

--[=[
    @type TProfileLifecycleSpec
    @within ServiceTypes
    Alias for `LifecycleTypes.TProfileLifecycleSpec`.
]=]
export type TProfileLifecycleSpec = LifecycleTypes.TProfileLifecycleSpec

--[=[
    @type TTeardownSpec
    @within ServiceTypes
    Alias for `CleanupTypes.TTeardownSpec`.
]=]
export type TTeardownSpec = CleanupTypes.TTeardownSpec

--[=[
    @interface TExternalServiceSpec
    @within ServiceTypes
    .Name string -- External Knit service name.
    .CacheAs string? -- Optional service field used to cache the service reference.
]=]
export type TExternalServiceSpec = {
	Name: string,
	CacheAs: string?,
}

--[=[
    @interface TExternalDependencySpec
    @within ServiceTypes
    .Name string -- Registry name for the resolved dependency.
    .From string -- Source registry module name.
    .Method string -- Source method name that returns the dependency value.
    .CacheAs string? -- Optional service field used to cache the resolved value.
]=]
export type TExternalDependencySpec = {
	Name: string,
	From: string,
	Method: string,
	CacheAs: string?,
}

--[=[
    @type TStartOrder
    @within ServiceTypes
    Ordered layer names used when starting the registry.
]=]
export type TStartOrder = { string }

--[=[
    @interface TContextService
    @within ServiceTypes
    .Name string -- Knit service name.
    .Client { [string]: any }? -- Optional client-facing API table.
    .WorldService TWorldServiceSpec? -- Optional context-owned world service.
    .Modules TModuleLayers? -- Layered module declarations.
    .Cache TCacheConfig? -- Cache declarations for service fields.
    .ExternalServices { TExternalServiceSpec }? -- External Knit services to register.
    .ExternalDependencies { TExternalDependencySpec }? -- External dependency values to register.
    .StartOrder TStartOrder? -- Registry start order override.
    .ProfileLifecycle TProfileLifecycleSpec? -- Profile lifecycle configuration.
    .Teardown TTeardownSpec? -- Teardown configuration.
]=]
export type TContextService = {
	Name: string,
	Client: { [string]: any }?,
	WorldService: TWorldServiceSpec?,
	Modules: TModuleLayers?,
	Cache: TCacheConfig?,
	ExternalServices: { TExternalServiceSpec }?,
	ExternalDependencies: { TExternalDependencySpec }?,
	StartOrder: TStartOrder?,
	ProfileLifecycle: TProfileLifecycleSpec?,
	Teardown: TTeardownSpec?,
	_registry: any?,
	[string]: any,
}

return table.freeze(ServiceTypes)
