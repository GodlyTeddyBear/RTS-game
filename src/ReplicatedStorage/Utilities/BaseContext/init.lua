--!strict

--[=[
    @class BaseContextEntry
    Entry-point module that forwards to `BaseContext`.
    @server
]=]

local BaseContext = require(script.src)
local Types = require(script.src.Types)

export type TModuleSpec = Types.TModuleSpec
export type TWorldServiceSpec = Types.TWorldServiceSpec
export type TModuleLayers = Types.TModuleLayers
export type TCacheMethodSpec = Types.TCacheMethodSpec
export type TCacheConfig = Types.TCacheConfig
export type TProfileLifecycleHandler = Types.TProfileLifecycleHandler
export type TProfileLifecycleSpec = Types.TProfileLifecycleSpec
export type TPlayerSyncOptions = Types.TPlayerSyncOptions
export type TTeardownFieldSpec = Types.TTeardownFieldSpec
export type TTeardownSpec = Types.TTeardownSpec
export type TExternalServiceSpec = Types.TExternalServiceSpec
export type TExternalDependencySpec = Types.TExternalDependencySpec
export type TStartOrder = Types.TStartOrder
export type TContextService = Types.TContextService
export type TBaseContext = BaseContext.TBaseContext

return BaseContext
