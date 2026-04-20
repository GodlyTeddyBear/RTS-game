--!strict

--[=[
	@class BuildingEvents
	Event registry for the Building bounded context.
	@server
]=]

--[=[
	@prop RestoreCompleted string
	@within BuildingEvents
	Fired when building restore + sync hydration has completed for a player. Emitted with: `(userId: number)`
]=]

local events = table.freeze({
	RestoreCompleted = "Building.RestoreCompleted",
})

-- Validation schemas: event name -> array of expected argument type strings
local schemas: { [string]: { string } } = {
	[events.RestoreCompleted] = { "number" },
}

return { events = events, schemas = schemas }
