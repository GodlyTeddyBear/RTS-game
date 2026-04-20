--!strict

--[=[
	@class LotEvents
	Event registry for the Lot bounded context.
	@server
]=]

--[=[
	@prop LotSpawned string
	@within LotEvents
	Fired when a new lot is spawned in the world. Emitted with: `(lotId: number)`
]=]

local events = table.freeze({
	LotSpawned = "Lot.LotSpawned",
})

-- Validation schemas: event name -> array of expected argument type strings
local schemas: { [string]: { string } } = {
	[events.LotSpawned] = { "number" },
}

return { events = events, schemas = schemas }
