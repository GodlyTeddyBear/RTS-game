--!strict

local Errors = {
	INVENTORY_FULL = "Inventory is full (maximum capacity reached)",
	CATEGORY_FULL = "Category capacity exceeded",
	INVALID_ITEM_ID = "Item does not exist",
	INVALID_SLOT_INDEX = "Slot index out of bounds",
	INVALID_QUANTITY = "Quantity must be between 1 and maxStack",
	SLOT_EMPTY = "Slot is empty",
	INSUFFICIENT_QUANTITY = "Not enough items in slot",
	ITEM_NOT_STACKABLE = "Item cannot be stacked",
	STACK_LIMIT_REACHED = "Stack limit reached for this item",
	DUPLICATE_SLOT = "Slot already occupied",
	INVALID_CATEGORY = "Invalid item category",
	INVALID_TRANSFER = "Cannot transfer item to destination",
}

table.freeze(Errors)
return Errors
