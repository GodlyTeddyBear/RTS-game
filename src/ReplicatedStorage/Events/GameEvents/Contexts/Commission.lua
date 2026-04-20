--!strict

--[=[
	@class CommissionEvents
	Event registry for the Commission bounded context.
	@server
]=]

--[=[
	@prop CommissionAccepted string
	@within CommissionEvents
	Fired when a player accepts a commission. Emitted with: `(userId: number, commissionId: string)`
]=]

--[=[
	@prop CommissionDelivered string
	@within CommissionEvents
	Fired when a commission is completed. Emitted with: `(userId: number, commissionId: string, rewards: table)`
]=]

--[=[
	@prop CommissionTierUnlocked string
	@within CommissionEvents
	Fired when a new commission tier is unlocked. Emitted with: `(userId: number, tierLevel: number)`
]=]

--[=[
	@prop CommissionAcceptedClient string
	@within CommissionEvents
	Fired when a commission is accepted on the client.
]=]

--[=[
	@prop CommissionDeliveredClient string
	@within CommissionEvents
	Fired when a commission is delivered on the client.
]=]

local events = table.freeze({
	CommissionAccepted = "Commission.CommissionAccepted",
	CommissionDelivered = "Commission.CommissionDelivered",
	CommissionTierUnlocked = "Commission.CommissionTierUnlocked",
	CommissionAcceptedClient = "Commission.CommissionAcceptedClient",
	CommissionDeliveredClient = "Commission.CommissionDeliveredClient",
})

-- Validation schemas: event name -> array of expected argument type strings
local schemas: { [string]: { string } } = {
	[events.CommissionAccepted] = { "number", "string" },
	[events.CommissionDelivered] = { "number", "string", "table" },
	[events.CommissionTierUnlocked] = { "number", "number" },
	[events.CommissionAcceptedClient] = {},
	[events.CommissionDeliveredClient] = {},
}

return { events = events, schemas = schemas }
