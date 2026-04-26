--!strict

local Forge = {}

local events = table.freeze({
	CraftingCompleted = "Forge.CraftingCompleted",
})

local schemas: { [string]: { string } } = {
	[events.CraftingCompleted] = { "number", "string", "string", "number" },
}

Forge.events = events
Forge.schemas = schemas

return Forge
