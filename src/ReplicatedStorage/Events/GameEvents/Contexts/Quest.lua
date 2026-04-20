--!strict

--[=[
	@class QuestEvents
	Event registry for the Quest bounded context.
	@server
]=]

--[=[
	@prop QuestCompleted string
	@within QuestEvents
	Fired when a player completes a quest. Emitted with: `(userId: number)`
]=]

local events = table.freeze({
	QuestCompleted = "Quest.QuestCompleted",
})

-- Validation schemas: event name -> array of expected argument type strings
local schemas: { [string]: { string } } = {
	[events.QuestCompleted] = { "number" },
}

return { events = events, schemas = schemas }
