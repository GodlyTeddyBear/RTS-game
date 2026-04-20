--!strict

--[=[
	@class InventoryEvents
	Event registry for the Inventory bounded context.
	@server
]=]

--[=[
	@prop ItemAdded string
	@within InventoryEvents
	Fired when an item is added to inventory. Emitted with: `(userId: number, itemId: string, quantity: number)`
]=]

--[=[
	@prop ItemPurchased string
	@within InventoryEvents
	Fired when an item is purchased. Emitted with: `(userId: number, itemId: string, cost: number, quantity: number)`
]=]

--[=[
	@prop ItemSold string
	@within InventoryEvents
	Fired when an item is sold. Emitted with: `(userId: number, itemId: string, salePrice: number, quantity: number)`
]=]

--[=[
	@prop PurchaseFailed string
	@within InventoryEvents
	Fired when a purchase attempt fails. Emitted with: `(userId: number, reason: string)`
]=]

--[=[
	@prop ItemBought string
	@within InventoryEvents
	Fired when a purchase completes on the client.
]=]

--[=[
	@prop ItemSoldClient string
	@within InventoryEvents
	Fired when an item is sold on the client.
]=]

local events = table.freeze({
	ItemAdded = "Inventory.ItemAdded",
	ItemPurchased = "Inventory.ItemPurchased",
	ItemSold = "Inventory.ItemSold",
	PurchaseFailed = "Inventory.PurchaseFailed",
	ItemBought = "Inventory.ItemBought",
	ItemSoldClient = "Inventory.ItemSoldClient",
})

-- Validation schemas: event name -> array of expected argument type strings
local schemas: { [string]: { string } } = {
	[events.ItemAdded] = { "number", "string", "number" },
	[events.ItemPurchased] = { "number", "string", "number", "number" },
	[events.ItemSold] = { "number", "string", "number", "number" },
	[events.PurchaseFailed] = { "number", "string" },
	[events.ItemBought] = {},
	[events.ItemSoldClient] = {},
}

return { events = events, schemas = schemas }
