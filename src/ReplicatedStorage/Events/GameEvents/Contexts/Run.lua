--!strict

--[=[
	@class Run
	Defines the run lifecycle GameEvents used by the Wave context.
	@server
	@client
]=]
local Run = {}

--[=[
	@prop events table
	@within Run
	Run event name constants.
]=]
local events = table.freeze({
	RunStarted = "Run.RunStarted",
	WaveStarted = "Run.WaveStarted",
	WaveEnded = "Run.WaveEnded",
	RunEnded = "Run.RunEnded",
})

--[=[
	@prop schemas table
	@within Run
	Validation schemas for each Run event.
]=]
local schemas: { [string]: { string } } = {
	[events.RunStarted] = {},
	[events.WaveStarted] = { "number", "boolean" },
	[events.WaveEnded] = { "number" },
	[events.RunEnded] = {},
}

Run.events = events
Run.schemas = schemas

return Run
