--!strict

--[=[
	@class Commander
	Defines commander lifecycle GameEvents used by server contexts.
	@server
	@client
]=]
local Commander = {}

--[=[
	@prop events table
	@within Commander
	Commander event name constants.
]=]
local events = table.freeze({
	CommanderDied = "Commander.CommanderDied",
})

--[=[
	@prop schemas table
	@within Commander
	Validation schemas for each Commander event.
]=]
local schemas: { [string]: { string } } = {
	[events.CommanderDied] = { "Instance" },
}

Commander.events = events
Commander.schemas = schemas

return Commander
