--!strict

--[=[
	@class CraftingEvents
	Event registry for the Crafting bounded context.
	@server
]=]

--[=[
	@prop CraftingStarted string
	@within CraftingEvents
	Fired when a crafting task begins. Emitted with: `(userId: number, recipeId: string)`
]=]

--[=[
	@prop CraftingCompleted string
	@within CraftingEvents
	Fired when a crafting task finishes. Emitted with: `(userId: number, recipeId: string, resultItemId: string, quantity: number)`
]=]

local events = table.freeze({
	CraftingStarted = "Crafting.CraftingStarted",
	CraftingCompleted = "Crafting.CraftingCompleted",
})

-- Validation schemas: event name -> array of expected argument type strings
local schemas: { [string]: { string } } = {
	[events.CraftingStarted] = { "number", "string" },
	[events.CraftingCompleted] = { "number", "string", "string", "number" },
}

return { events = events, schemas = schemas }
