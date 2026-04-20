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
	WaveStarted = "Run.WaveStarted",
	RunEnded = "Run.RunEnded",
})

--[=[
	@prop schemas table
	@within Run
	Validation schemas for each Run event.
]=]
local schemas: { [string]: { string } } = {
	[events.WaveStarted] = { "number", "boolean" },
	[events.RunEnded] = {},
}

Run.events = events
Run.schemas = schemas

return Run
