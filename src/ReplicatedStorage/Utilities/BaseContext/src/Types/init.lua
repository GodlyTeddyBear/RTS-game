--!strict

--[=[
    @class Types
    Re-exports the shared BaseContext type aliases for configuration and service tables.
    @server
]=]

local ModuleTypes = require(script.ModuleTypes)
local CacheTypes = require(script.CacheTypes)
local CleanupTypes = require(script.CleanupTypes)
local LifecycleTypes = require(script.LifecycleTypes)
local ServiceTypes = require(script.ServiceTypes)

local Types = {}

--[=[
    @type TModuleSpec
    @within Types
    Re-export of `ModuleTypes.TModuleSpec`.
]=]
export type TModuleSpec = ModuleTypes.TModuleSpec

--[=[
    @type TWorldServiceSpec
    @within Types
    Re-export of `ModuleTypes.TWorldServiceSpec`.
]=]
export type TWorldServiceSpec = ModuleTypes.TWorldServiceSpec

--[=[
    @type TModuleLayers
    @within Types
    Re-export of `ModuleTypes.TModuleLayers`.
]=]
export type TModuleLayers = ModuleTypes.TModuleLayers

--[=[
    @type TCacheMethodSpec
    @within Types
    Re-export of `CacheTypes.TCacheMethodSpec`.
]=]
export type TCacheMethodSpec = CacheTypes.TCacheMethodSpec

--[=[
    @type TCacheConfig
    @within Types
    Re-export of `CacheTypes.TCacheConfig`.
]=]
export type TCacheConfig = CacheTypes.TCacheConfig

--[=[
    @type TProfileLifecycleHandler
    @within Types
    Re-export of `LifecycleTypes.TProfileLifecycleHandler`.
]=]
export type TProfileLifecycleHandler = LifecycleTypes.TProfileLifecycleHandler

--[=[
    @type TProfileLifecycleSpec
    @within Types
    Re-export of `LifecycleTypes.TProfileLifecycleSpec`.
]=]
export type TProfileLifecycleSpec = LifecycleTypes.TProfileLifecycleSpec

--[=[
    @type TPlayerSyncOptions
    @within Types
    Re-export of `LifecycleTypes.TPlayerSyncOptions`.
]=]
export type TPlayerSyncOptions = LifecycleTypes.TPlayerSyncOptions

--[=[
    @type TTeardownFieldSpec
    @within Types
    Re-export of `CleanupTypes.TTeardownFieldSpec`.
]=]
export type TTeardownFieldSpec = CleanupTypes.TTeardownFieldSpec

--[=[
    @type TTeardownSpec
    @within Types
    Re-export of `CleanupTypes.TTeardownSpec`.
]=]
export type TTeardownSpec = CleanupTypes.TTeardownSpec

--[=[
    @type TExternalServiceSpec
    @within Types
    Re-export of `ServiceTypes.TExternalServiceSpec`.
]=]
export type TExternalServiceSpec = ServiceTypes.TExternalServiceSpec

--[=[
    @type TExternalDependencySpec
    @within Types
    Re-export of `ServiceTypes.TExternalDependencySpec`.
]=]
export type TExternalDependencySpec = ServiceTypes.TExternalDependencySpec

--[=[
    @type TStartOrder
    @within Types
    Re-export of `ServiceTypes.TStartOrder`.
]=]
export type TStartOrder = ServiceTypes.TStartOrder

--[=[
    @type TContextService
    @within Types
    Re-export of `ServiceTypes.TContextService`.
]=]
export type TContextService = ServiceTypes.TContextService

return table.freeze(Types)
