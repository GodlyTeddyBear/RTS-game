--!strict

--[=[
	@class Errors
	Error message constants for Shop context operations.
	@server
]=]
return table.freeze({
	ITEM_LOCKED = "This item has not been unlocked yet",
	INVALID_ITEM_ID = "Item does not exist",
	ITEM_NOT_BUYABLE = "Item cannot be purchased",
	ITEM_NOT_SELLABLE = "Item cannot be sold",
	INSUFFICIENT_GOLD = "Not enough gold",
	INVALID_QUANTITY = "Quantity must be at least 1",
	INVALID_SLOT = "Invalid inventory slot",
	SLOT_EMPTY = "Inventory slot is empty",
	INSUFFICIENT_ITEM_QUANTITY = "Not enough items in slot to sell",
	INVENTORY_FULL = "Inventory is full",
	BUY_FAILED = "Purchase failed unexpectedly",
	SELL_FAILED = "Sale failed unexpectedly",
	PLAYER_NOT_FOUND = "Player not found",
})
