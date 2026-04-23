--!strict

--[=[
    @class Config
    Frozen constants and defaults used by BaseContext validation, module registration,
    cache resolution, and lifecycle wiring.
    @server
    @prop KnownLayers { [string]: boolean } -- Frozen set of supported module layers.
    @prop LayerOrder { string } -- Canonical module layer iteration order.
    @prop DefaultStartOrder { string } -- Default registry start order when a service omits one.
    @prop DefaultProfileLoadedCache string -- Default cache field for profile-loaded connections.
    @prop DefaultProfileSavingCache string -- Default cache field for profile-saving connections.
    @prop DefaultPlayerRemovingCache string -- Default cache field for player-removing connections.
    @prop DefaultHydrateMethod string -- Default sync method name used when hydrating players.
    @prop DefaultRemoveMethod string -- Default sync method name used when removing players.
    @prop DefaultPollMethod string -- Default scheduler poll method name.
    @prop DefaultTickMethod string -- Default scheduler tick method name.
    @prop DefaultSyncMethod string -- Default scheduler sync method name.
]=]
local Config = {
	KnownLayers = table.freeze({
		Infrastructure = true,
		Domain = true,
		Application = true,
	}),

	LayerOrder = table.freeze({
		"Infrastructure",
		"Domain",
		"Application",
	}),

	DefaultStartOrder = table.freeze({
		"Domain",
		"Infrastructure",
		"Application",
	}),

	DefaultProfileLoadedCache = "_profileLoadedConnection",
	DefaultProfileSavingCache = "_profileSavingConnection",
	DefaultPlayerRemovingCache = "_playerRemovingConnection",

	DefaultHydrateMethod = "HydratePlayer",
	DefaultRemoveMethod = "RemovePlayer",

	DefaultPollMethod = "Poll",
	DefaultTickMethod = "Tick",
	DefaultSyncMethod = "SyncDirtyEntities",
}

return table.freeze(Config)
