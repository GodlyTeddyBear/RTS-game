--!strict

--[=[
	@class PersistenceEvents
	Event registry for persistence and player lifecycle events.
	@server
]=]

--[=[
	@prop ProfileLoaded string
	@within PersistenceEvents
	Fired when a player's profile data is loaded from storage. Emitted with: `(player: Instance)`
]=]

--[=[
	@prop ProfileSaving string
	@within PersistenceEvents
	Fired when a player's profile data is about to be saved. Emitted with: `(player: Instance)`
]=]

--[=[
	@prop PlayerReady string
	@within PersistenceEvents
	Fired when a player is fully initialized and ready for context loading. Emitted with: `(player: Instance)`
]=]

local events = table.freeze({
	ProfileLoaded = "Persistence.ProfileLoaded",
	ProfileSaving = "Persistence.ProfileSaving",
	PlayerReady = "Persistence.PlayerReady",
})

-- Validation schemas: event name -> array of expected argument type strings
local schemas: { [string]: { string } } = {
	[events.ProfileLoaded] = { "Instance" },
	[events.ProfileSaving] = { "Instance" },
	[events.PlayerReady] = { "Instance" },
}

return { events = events, schemas = schemas }
