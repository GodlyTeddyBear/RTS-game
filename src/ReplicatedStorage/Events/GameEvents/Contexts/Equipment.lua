--!strict

--[=[
	@class EquipmentEvents
	Event registry for the Equipment bounded context.
	@server
]=]

--[=[
	@prop EquipmentChanged string
	@within EquipmentEvents
	Fired when a player equips or unequips an item. Emitted with: `(userId: number, itemId: string, slotType: string, action: string)`
]=]

local events = table.freeze({
	EquipmentChanged = "Equipment.EquipmentChanged",
})

-- Validation schemas: event name -> array of expected argument type strings
local schemas: { [string]: { string } } = {
	[events.EquipmentChanged] = { "number", "string", "string", "string" },
}

return { events = events, schemas = schemas }
