--!strict

--[=[
	@class DialogueEvents
	Event registry for dialogue system events.
	@server
]=]

--[=[
	@prop FlagSet string
	@within DialogueEvents
	Fired when a dialogue flag is set. Emitted with: `(userId: number, flagName: string)`
]=]

local events = table.freeze({
	FlagSet = "Dialogue.FlagSet",
	OptionSelected = "Dialogue.OptionSelected",
})

-- Validation schemas: event name -> array of expected argument type strings
local schemas: { [string]: { string } } = {
	[events.FlagSet] = { "number", "string" },
	[events.OptionSelected] = { "string" },
}

return { events = events, schemas = schemas }
