--!strict

export type TCleanupMethod = boolean | string
export type TStashState = "Active" | "Cleaning" | "Destroyed"
export type TCleanupOperation =
	"Cleanup"
	| "Destroy"
	| "Detach"
	| "RemoveAndCleanup"
	| "DestroyScope"
	| "DestroyAllScopes"
	| "StaticCleanup"

export type TAddOptions = {
	CleanupMethod: TCleanupMethod?,
	Key: any?,
	Label: string?,
}

export type TCleanupFailure = {
	Label: string?,
	Key: any?,
	Resource: any?,
	ResourceType: string?,
	CleanupMethod: TCleanupMethod?,
	Operation: TCleanupOperation,
	ErrorMessage: string,
	ScopeName: string?,
	ScopePath: string?,
}

export type TCleanupReport = {
	Success: boolean,
	FailureCount: number,
	ResourceCountCleaned: number,
	ScopeCountCleaned: number,
	Operation: TCleanupOperation,
	Failures: { TCleanupFailure },
	CleanedChildren: { string }?,
}

export type TStash = {
	Add: (self: TStash, resource: any, cleanupMethodOrOptions: (TCleanupMethod | TAddOptions)?, keyOrOptions: any?) -> any,
	AddCallback: (self: TStash, label: string, callback: () -> (), keyOrOptions: any?) -> (() -> ()),
	AddConnection: (self: TStash, connection: RBXScriptConnection, keyOrOptions: any?) -> RBXScriptConnection,
	AddFunction: (self: TStash, callback: () -> (), keyOrOptions: any?) -> (() -> ()),
	AddInstance: (self: TStash, instance: Instance, keyOrOptions: any?) -> Instance,
	AddPromise: (self: TStash, promiseObject: any, keyOrOptions: any?) -> any,
	AddStash: (self: TStash, stash: TStash, keyOrOptions: any?) -> TStash,
	AddTask: (self: TStash, cleanupThread: thread, keyOrOptions: any?) -> thread,
	AddThread: (self: TStash, cleanupThread: thread, keyOrOptions: any?) -> thread,
	Cleanup: (self: TStash) -> TCleanupReport,
	Detach: (self: TStash, key: any) -> boolean,
	Destroy: (self: TStash) -> TCleanupReport,
	DestroyScope: (self: TStash, name: string) -> TCleanupReport,
	DestroyAllScopes: (self: TStash) -> TCleanupReport,
	Count: (self: TStash) -> number,
	CountScopes: (self: TStash) -> number,
	Get: (self: TStash, key: any) -> any?,
	GetAll: (self: TStash) -> { [any]: any },
	GetScopeNames: (self: TStash) -> { string },
	GetState: (self: TStash) -> TStashState,
	GetScope: (self: TStash, name: string) -> TStash?,
	Has: (self: TStash, key: any) -> boolean,
	HasScope: (self: TStash, name: string) -> boolean,
	IsCleaning: (self: TStash) -> boolean,
	IsDestroyed: (self: TStash) -> boolean,
	LinkToInstance: (self: TStash, instance: Instance, allowMultiple: boolean?) -> RBXScriptConnection,
	RemoveAndCleanup: (self: TStash, key: any) -> TCleanupReport,
	RemoveScope: (self: TStash, name: string) -> boolean,
	Scope: (self: TStash, name: string) -> TStash,
}

export type TStashPlus = {
	new: () -> TStash,
	CanCleanup: (resource: any, cleanupMethod: TCleanupMethod?) -> (boolean, string?),
	Cleanup: (resource: any, cleanupMethod: TCleanupMethod?) -> TCleanupReport,
	ResolveCleanupMethod: (resource: any, cleanupMethod: TCleanupMethod?) -> TCleanupMethod,
}

local Types = {}

return Types
