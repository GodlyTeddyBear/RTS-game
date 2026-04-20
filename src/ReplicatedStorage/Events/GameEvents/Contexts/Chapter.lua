--!strict

--[=[
	@class ChapterEvents
	Event registry for the Chapter bounded context.
	@server
]=]

--[=[
	@prop ChapterAdvanced string
	@within ChapterEvents
	Fired when a player advances to a new chapter. Emitted with: `(userId: number, newChapter: number)`
]=]

local events = table.freeze({
	ChapterAdvanced = "Chapter.ChapterAdvanced",
})

-- Validation schemas: event name -> array of expected argument type strings
local schemas: { [string]: { string } } = {
	[events.ChapterAdvanced] = { "number", "number" },
}

return { events = events, schemas = schemas }
