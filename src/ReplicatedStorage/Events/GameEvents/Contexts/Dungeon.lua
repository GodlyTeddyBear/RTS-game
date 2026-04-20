--!strict

--[=[
	@class DungeonEvents
	Event registry for the Dungeon bounded context.
	@server
]=]

--[=[
	@prop DungeonReady string
	@within DungeonEvents
	Fired when a dungeon instance is fully initialized. Emitted with: `(dungeonInstanceId: number, difficultyTier: string)`
]=]

--[=[
	@prop DungeonCleanedUp string
	@within DungeonEvents
	Fired when a dungeon instance is cleaned up and removed. Emitted with: `(dungeonInstanceId: number)`
]=]

--[=[
	@prop DungeonComplete string
	@within DungeonEvents
	Fired when a dungeon is fully completed. Emitted with: `(dungeonInstanceId: number, completionStatus: string)`
]=]

--[=[
	@prop WaveAreaGenerated string
	@within DungeonEvents
	Fired when a wave's play area is generated. Emitted with: `(dungeonInstanceId: number, waveNumber: number, areaType: string)`
]=]

local events = table.freeze({
	DungeonReady = "Dungeon.DungeonReady",
	DungeonCleanedUp = "Dungeon.DungeonCleanedUp",
	DungeonComplete = "Dungeon.DungeonComplete",
	WaveAreaGenerated = "Dungeon.WaveAreaGenerated",
})

-- Validation schemas: event name -> array of expected argument type strings
local schemas: { [string]: { string } } = {
	[events.DungeonReady] = { "number", "string" },
	[events.DungeonCleanedUp] = { "number" },
	[events.DungeonComplete] = { "number", "string" },
	[events.WaveAreaGenerated] = { "number", "number", "string" },
}

return { events = events, schemas = schemas }
