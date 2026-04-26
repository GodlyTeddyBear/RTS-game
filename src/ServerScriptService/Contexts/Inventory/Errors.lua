--!strict

local Errors = {
	INVALID_USER_ID = "UserId must be a positive number",
	INVENTORY_FULL = "Inventory is full",
	INVALID_ITEM_ID = "Item does not exist",
	INVALID_SLOT_INDEX = "Slot index out of bounds",
	INVALID_QUANTITY = "Quantity must be at least 1",
	SLOT_EMPTY = "Slot is empty",
	INSUFFICIENT_QUANTITY = "Not enough items in slot",
}

return table.freeze(Errors)
