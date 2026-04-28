--!strict

local Combat = {}

local events = table.freeze({
	ActorRemoving = "Combat.ActorRemoving",
})

local schemas: { [string]: { string } } = table.freeze({
	[events.ActorRemoving] = { "string", "number" },
})

Combat.events = events
Combat.schemas = schemas

return Combat
