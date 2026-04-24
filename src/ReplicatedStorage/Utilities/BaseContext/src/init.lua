--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Janitor = require(ReplicatedStorage.Packages.Janitor)
local WrapContext = require(ReplicatedStorage.Utilities.WrapContext)
local Registry = require(script.Parent.Parent.Registry)

local BootstrapMethods = require(script.Public.Bootstrap)
local CacheMethods = require(script.Public.Cache)
local CleanupMethods = require(script.Public.Cleanup)
local ModuleMethods = require(script.Public.Modules)
local ProfileMethods = require(script.Public.Profile)
local RegistryMethods = require(script.Public.Registry)
local SchedulerMethods = require(script.Public.Scheduler)
local SignalsMethods = require(script.Public.Signals)
local StartMethods = require(script.Public.Start)
local Types = require(script.Types)

type RegistryContext = Registry.RegistryContext
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
export type TBaseContext = {
	KnitInit: (self: TBaseContext) -> (),
	KnitStart: (self: TBaseContext) -> (),
	GetRegistry: (self: TBaseContext) -> any,
	Destroy: (self: TBaseContext) -> any,
	Cleanup: (self: TBaseContext) -> any,
	AddCleanup: (self: TBaseContext, resource: any, cleanupMethod: string?) -> any,
	AddCleanupField: (self: TBaseContext, fieldName: string, cleanupMethod: string?) -> (),
	RequireProfileLifecycle: (self: TBaseContext) -> any,
	GetProfileLoaderName: (self: TBaseContext) -> string,
	RegisterProfileLoader: (self: TBaseContext) -> (),
	StartProfileLifecycle: (self: TBaseContext) -> (),
	OnProfileLoaded: (self: TBaseContext, callbackOrMethodName: any, cacheAs: string?) -> any,
	OnProfileSaving: (self: TBaseContext, callbackOrMethodName: any, cacheAs: string?) -> any,
	OnProfileRemoving: (self: TBaseContext, callbackOrMethodName: any, cacheAs: string?) -> any,
	BackfillLoadedProfiles: (self: TBaseContext, callbackOrMethodName: any) -> (),
	NotifyProfileLoaded: (self: TBaseContext, player: Player) -> (),
	IsProfileLoaded: (self: TBaseContext, player: Player) -> boolean,
	RegisterSchedulerSystem: (self: TBaseContext, phaseName: string, callback: () -> ()) -> (),
	RegisterMethodSystem: (self: TBaseContext, phaseName: string, targetField: string, methodName: string) -> (),
	RegisterPollSystem: (self: TBaseContext, targetField: string, methodName: string?, phaseName: string) -> (),
	RegisterTickSystem: (self: TBaseContext, targetField: string, methodName: string?, phaseName: string) -> (),
	RegisterDeltaTickSystem: (self: TBaseContext, targetField: string, methodName: string?, phaseName: string) -> (),
	RegisterSyncSystem: (self: TBaseContext, targetField: string, methodName: string?, phaseName: string) -> (),
	GetSchedulerDeltaTime: (self: TBaseContext) -> number,
	OnGameEvent: (self: TBaseContext, eventName: string, callback: (...any) -> (), cacheAs: string?) -> any,
	GetContextEvent: (self: TBaseContext, contextName: string, eventName: string) -> string,
	OnContextEvent: (self: TBaseContext, contextName: string, eventName: string, callback: (...any) -> (), cacheAs: string?) -> any,
	EmitGameEvent: (self: TBaseContext, eventName: string, ...any) -> (),
	EmitContextEvent: (self: TBaseContext, contextName: string, eventName: string, ...any) -> (),
	OnPlayerAdded: (self: TBaseContext, callback: (Player) -> (), cacheAs: string?) -> any,
	OnPlayerRemoving: (self: TBaseContext, callback: (Player) -> (), cacheAs: string?) -> any,
	ForEachPlayer: (self: TBaseContext, callback: (Player) -> ()) -> (),
	HandleExistingAndAddedPlayers: (self: TBaseContext, callback: (Player) -> (), cacheAs: string?) -> any,
	HydrateExistingAndAddedPlayers: (self: TBaseContext, syncServiceField: string, options: TPlayerSyncOptions?) -> any,
	RemoveLeavingPlayersByUserId: (self: TBaseContext, syncServiceField: string, options: TPlayerSyncOptions?) -> any,
	TrackSignalConnection: (self: TBaseContext, connection: any, cacheAs: string?) -> any,
	CallSyncServiceForPlayer: (self: TBaseContext, syncServiceField: string, methodName: string, player: Player) -> (),
	CallSyncServiceWithUserId: (self: TBaseContext, syncServiceField: string, methodName: string, userId: number) -> (),
}

--[=[
	@class BaseContext
	Owns the shared bootstrap wrapper for a Knit service table and wires the
	registry, module, cache, profile, signal, scheduler, and cleanup helpers.
	@server
]=]
local BaseContext = {}
BaseContext.__index = BaseContext

-- ── Private ───────────────────────────────────────────────────────────────────

local function ApplyMethods(target: any, methods: { [string]: any })
	for name, method in pairs(methods) do
		target[name] = method
	end
end

-- ── Public ────────────────────────────────────────────────────────────────────

--[=[
	Creates a base context wrapper around a Knit service table.
	@within BaseContext
	@param service TContextService -- Knit service table created by `Knit.CreateService`.
	@param registryContext RegistryContext? -- Registry context, defaults to `"Server"`.
	@return BaseContext -- Base context wrapper.
]=]
function BaseContext.new(service: TContextService, registryContext: RegistryContext?): TBaseContext
	assert(service ~= nil, "BaseContext.new requires a service table")
	assert(type(service.Name) == "string" and service.Name ~= "", "BaseContext.new requires service.Name")
	WrapContext(service, service.Name)

	local self = setmetatable({}, BaseContext)
	self._service = service
	self._registryContext = registryContext or "Server"
	self._initializedModules = {}
	self._janitor = Janitor.new()
	self._cleanupResults = nil
	self._destroyed = false
	return self :: any
end

ApplyMethods(BaseContext, BootstrapMethods)
ApplyMethods(BaseContext, CacheMethods)
ApplyMethods(BaseContext, CleanupMethods)
ApplyMethods(BaseContext, ModuleMethods)
ApplyMethods(BaseContext, ProfileMethods)
ApplyMethods(BaseContext, RegistryMethods)
ApplyMethods(BaseContext, SchedulerMethods)
ApplyMethods(BaseContext, SignalsMethods)
ApplyMethods(BaseContext, StartMethods)

return BaseContext
