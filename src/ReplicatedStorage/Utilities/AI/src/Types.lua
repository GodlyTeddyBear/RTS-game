--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AiAdapterFactory = require(ReplicatedStorage.Utilities.AI.AdapterFactory)
local AiRuntime = require(ReplicatedStorage.Utilities.AI.Runtime)
local Enums = require(script.Parent.Enums)

--[=[
	@class AITypes
	Grouped type exports for the shared `AI` facade.
	@server
	@client
]=]

local Types = {
	Runtime = AiRuntime.Types,
	AdapterFactory = AiAdapterFactory.Types,
	Enums = Enums,
}

export type TRuntimeConfig = AiRuntime.TConfig
export type TFrameContext = AiRuntime.TFrameContext
export type TActorAdapter = AiRuntime.TActorAdapter
export type TRunFrameResult = AiRuntime.TRunFrameResult
export type TCleanupResult = AiRuntime.TCleanupResult
export type TAdapterConfig = AiAdapterFactory.TConfig
export type TFactoryAdapterConfig = AiAdapterFactory.TFactoryConfig
type TConditionRegistry = { [string]: (options: any?) -> any }
type TCommandRegistry = { [string]: (options: any?) -> any }
type THook = AiRuntime.THook
type TErrorSinkPayload = AiRuntime.TErrorSinkPayload
export type TSystemConfig = {
	Conditions: TConditionRegistry,
	Commands: TCommandRegistry,
	Hooks: { THook }?,
	GlobalHooks: { THook }?,
	ErrorSink: ((payload: TErrorSinkPayload) -> ())?,
}

export type TActorRegistration = {
	ActorType: string,
	Adapter: TActorAdapter,
	Actions: any?,
}

export type TActionPack = {
	Name: string,
	Definitions: { [string]: any },
}

export type TActorBundle = {
	ActorType: string,
	Adapter: TActorAdapter,
	Actions: { [string]: any }?,
	ActionPacks: { TActionPack }?,
	DefaultBehaviorName: string?,
	Hooks: { any }?,
	TickInterval: number?,
	InitializeActionState: boolean?,
}

export type TActorPackage = {
	ActorBundle: TActorBundle,
	Behaviors: { [string]: any }?,
	Aliases: { [string]: string }?,
	ArchetypeDefaults: { [string]: string }?,
	FallbackBehaviorName: string?,
	TickInterval: number?,
	InitializeActionState: boolean?,
}

export type TBehaviorRegistration = {
	Name: string,
	Definition: any,
}

export type TResolveBehaviorOptions = {
	BehaviorName: string?,
	ArchetypeName: string?,
}

export type TAssignmentRequest = {
	ActorType: string,
	BehaviorName: string?,
	ArchetypeName: string?,
}

export type TAssignmentSource =
	"Explicit"
	| "ActorBundleDefault"
	| "ActorTypeDefault"
	| "ArchetypeDefault"
	| "Fallback"
	| "Missing"

export type TAssignmentResult = {
	ActorType: string,
	BehaviorName: string?,
	ResolvedBehaviorName: string?,
	Tree: any?,
	Source: TAssignmentSource,
	ArchetypeName: string?,
	Found: boolean,
}

export type TActorSetupRequest = {
	Entity: number,
	ActorType: string,
	BehaviorName: string?,
	ArchetypeName: string?,
}

export type TActorSetupResult = {
	Entity: number,
	ActorType: string,
	Assignment: TAssignmentResult,
	Tree: any?,
	BehaviorName: string?,
	ResolvedBehaviorName: string?,
	Found: boolean,
	TickInterval: number?,
	InitializeActionState: boolean,
	SetupDefaults: TSetupDefaults,
}

export type TActorSetupWriteConfig = {
	WriteSetup: (setupResult: TActorSetupResult) -> (),
	ClearActionState: ((setupResult: TActorSetupResult) -> ())?,
	OnMissingBehavior: ((setupResult: TActorSetupResult) -> ())?,
}

type TFactorySetupWriterSurface = string | ((factory: any, setupResult: TActorSetupResult) -> ())

export type TFactorySetupWriteConfig = {
	Factory: any,
	WriteSetup: TFactorySetupWriterSurface,
	ClearActionState: TFactorySetupWriterSurface?,
	OnMissingBehavior: TFactorySetupWriterSurface?,
}

export type TActorSetupWriteResult = {
	Entity: number,
	ActorType: string,
	Found: boolean,
	WroteSetup: boolean,
	BehaviorName: string?,
	ResolvedBehaviorName: string?,
}

export type TRegisterableRuntime = {
	RegisterActorType: (self: TRegisterableRuntime, actorType: string, adapter: TActorAdapter) -> (),
	RegisterActions: (self: TRegisterableRuntime, actionDefinitions: any) -> (),
	BuildTree: (self: TRegisterableRuntime, definition: any) -> any,
}

export type TBehaviorCatalogConfig = {
	Behaviors: { [string]: any }?,
	Aliases: { [string]: string }?,
	ActorDefaults: { [string]: string }?,
	ArchetypeDefaults: { [string]: string }?,
	FallbackBehaviorName: string?,
}

export type TBehaviorCatalogResolved = {
	Behaviors: { [string]: any },
	Aliases: { [string]: string },
	ActorDefaults: { [string]: string },
	ArchetypeDefaults: { [string]: string },
	FallbackBehaviorName: string?,
}

export type TBehaviorCatalog = {
	AddBehavior: (self: TBehaviorCatalog, name: string, definition: any) -> TBehaviorCatalog,
	AddBehaviors: (self: TBehaviorCatalog, behaviorDefinitions: { [string]: any }) -> TBehaviorCatalog,
	SetAlias: (self: TBehaviorCatalog, aliasName: string, behaviorName: string) -> TBehaviorCatalog,
	SetActorDefault: (self: TBehaviorCatalog, actorType: string, behaviorName: string) -> TBehaviorCatalog,
	SetArchetypeDefault: (self: TBehaviorCatalog, archetypeName: string, behaviorName: string) -> TBehaviorCatalog,
	SetFallbackBehavior: (self: TBehaviorCatalog, behaviorName: string) -> TBehaviorCatalog,
	Build: (self: TBehaviorCatalog, runtime: TRegisterableRuntime) -> TBehaviorCatalogResolved,
	GetBehavior: (self: TBehaviorCatalog, name: string) -> any?,
	ResolveForActor: (self: TBehaviorCatalog, actorType: string, options: TResolveBehaviorOptions?) -> any?,
	GetState: (self: TBehaviorCatalog) -> string,
	Dispose: (self: TBehaviorCatalog) -> (),
}

export type TBuildManifest = {
	ActorTypes: { string },
	ActorBundleTypes: { string },
	ActionIds: { string },
	ActionPacks: { string },
	BehaviorNames: { string },
	Aliases: { [string]: string },
	ActorDefaults: { [string]: string },
	ArchetypeDefaults: { [string]: string },
	FallbackBehaviorName: string?,
	LoadedHookCount: number,
}

export type TBuildDiagnostics = {
	BuilderState: string,
	BuildStage: string,
	DuplicateOverwrites: { string },
	Counts: { [string]: number },
}

export type TAssignmentDefaults = {
	ActorBundleDefaults: { [string]: string },
	ActorTypeDefaults: { [string]: string },
	ArchetypeDefaults: { [string]: string },
	FallbackBehaviorName: string?,
	ResolutionOrder: { string },
}

export type TSetupDefaults = {
	DefaultTickInterval: number?,
	TickIntervalByActorType: { [string]: number },
	ClearActionStateOnWrite: boolean?,
	InitializeActionStateByActorType: { [string]: boolean },
}

export type TSystemBuildResult = {
	Runtime: TRegisterableRuntime,
	Behaviors: { [string]: any },
	Actors: { TActorRegistration },
	Actions: { [string]: any },
	ActionPacks: { TActionPack },
	ActorBundles: { TActorBundle },
	ActorDefaults: { [string]: { DefaultBehaviorName: string? } },
	AssignmentDefaults: TAssignmentDefaults,
	SetupDefaults: TSetupDefaults,
	Catalog: TBehaviorCatalogResolved,
	Manifest: TBuildManifest,
	Diagnostics: TBuildDiagnostics,
}

export type TSystemBuilder = {
	AddHooks: (self: TSystemBuilder, hooks: { any }) -> TSystemBuilder,
	LoadHooks: (self: TSystemBuilder, folder: Instance, predicate: ((ModuleScript) -> boolean)?) -> TSystemBuilder,
	AddActions: (self: TSystemBuilder, actionDefinitions: { [string]: any }) -> TSystemBuilder,
	AddActionPack: (self: TSystemBuilder, actionPack: TActionPack) -> TSystemBuilder,
	LoadActions: (self: TSystemBuilder, folder: Instance, predicate: ((ModuleScript) -> boolean)?) -> TSystemBuilder,
	AddActor: (self: TSystemBuilder, registration: TActorRegistration) -> TSystemBuilder,
	AddActorBundle: (self: TSystemBuilder, bundle: TActorBundle) -> TSystemBuilder,
	AddActorBundles: (self: TSystemBuilder, bundles: { TActorBundle }) -> TSystemBuilder,
	AddActorPackage: (self: TSystemBuilder, actorPackage: TActorPackage) -> TSystemBuilder,
	AddActorPackages: (self: TSystemBuilder, actorPackages: { TActorPackage }) -> TSystemBuilder,
	SetBehaviorAlias: (self: TSystemBuilder, aliasName: string, behaviorName: string) -> TSystemBuilder,
	SetActorDefault: (self: TSystemBuilder, actorType: string, behaviorName: string) -> TSystemBuilder,
	SetArchetypeDefault: (self: TSystemBuilder, archetypeName: string, behaviorName: string) -> TSystemBuilder,
	SetFallbackBehavior: (self: TSystemBuilder, behaviorName: string) -> TSystemBuilder,
	SetActorTickInterval: (self: TSystemBuilder, actorType: string, tickInterval: number) -> TSystemBuilder,
	SetDefaultTickInterval: (self: TSystemBuilder, tickInterval: number) -> TSystemBuilder,
	SetClearActionStateOnSetup: (self: TSystemBuilder, enabled: boolean) -> TSystemBuilder,
	AddBehavior: (self: TSystemBuilder, name: string, definition: any) -> TSystemBuilder,
	AddBehaviors: (self: TSystemBuilder, behaviorDefinitions: { [string]: any }) -> TSystemBuilder,
	LoadBehaviors: (self: TSystemBuilder, folder: Instance, predicate: ((ModuleScript) -> boolean)?) -> TSystemBuilder,
	GetState: (self: TSystemBuilder) -> string,
	Dispose: (self: TSystemBuilder) -> (),
	Build: (self: TSystemBuilder) -> TSystemBuildResult,
}

return table.freeze(Types)
