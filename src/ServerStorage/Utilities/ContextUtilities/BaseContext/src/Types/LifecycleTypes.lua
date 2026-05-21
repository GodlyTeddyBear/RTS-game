--!strict

--[=[
    @class LifecycleTypes
    Shared profile lifecycle and sync option types for BaseContext.
    @server
]=]

local LifecycleTypes = {}

--[=[
    @type TProfileLifecycleHandler
    @within LifecycleTypes
    Callback or service method name used by profile lifecycle wiring.
]=]
export type TProfileLifecycleHandler = string | ((Player) -> ())

--[=[
    @interface TProfileLifecycleSpec
    @within LifecycleTypes
    .LoaderName string -- Profile loader name registered with the lifecycle manager.
    .OnLoaded TProfileLifecycleHandler -- Handler for loaded profiles.
    .OnSaving TProfileLifecycleHandler? -- Optional handler for profile saving.
    .OnRemoving TProfileLifecycleHandler? -- Optional handler for player removal.
    .Backfill boolean? -- Whether to replay loaded players during startup.
]=]
export type TProfileLifecycleSpec = {
	LoaderName: string,
	OnLoaded: TProfileLifecycleHandler,
	OnSaving: TProfileLifecycleHandler?,
	OnRemoving: TProfileLifecycleHandler?,
	Backfill: boolean?,
}

--[=[
    @interface TPlayerSyncOptions
    @within LifecycleTypes
    .MethodName string? -- Override for the sync method name.
    .CacheAs string? -- Optional service field used to cache the returned connection.
]=]
export type TPlayerSyncOptions = {
	MethodName: string?,
	CacheAs: string?,
}

return table.freeze(LifecycleTypes)
