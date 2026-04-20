--!strict

--[=[
    @class Errors
    Frozen table of error message constants for the Inventory context.
    @server
]=]

--[=[
    @prop INVENTORY_FULL string
    @within Errors
    Emitted when the inventory has reached maximum slot capacity.
]=]

--[=[
    @prop CATEGORY_FULL string
    @within Errors
    Emitted when a category has reached its slot capacity.
]=]

--[=[
    @prop INVALID_ITEM_ID string
    @within Errors
    Emitted when the provided item ID does not exist in ItemConfig.
]=]

--[=[
    @prop INVALID_SLOT_INDEX string
    @within Errors
    Emitted when a slot index is out of the inventory's valid range.
]=]

--[=[
    @prop INVALID_QUANTITY string
    @within Errors
    Emitted when a quantity is less than 1 or exceeds the item's maxStack.
]=]

--[=[
    @prop SLOT_EMPTY string
    @within Errors
    Emitted when an operation targets a slot that contains no item.
]=]

--[=[
    @prop INSUFFICIENT_QUANTITY string
    @within Errors
    Emitted when the slot does not have enough items to satisfy a remove request.
]=]

--[=[
    @prop ITEM_NOT_STACKABLE string
    @within Errors
    Emitted when a stack operation is attempted on a non-stackable item.
]=]

--[=[
    @prop STACK_LIMIT_REACHED string
    @within Errors
    Emitted when a slot is already at its maximum stack size.
]=]

--[=[
    @prop DUPLICATE_SLOT string
    @within Errors
    Emitted when attempting to place an item into an already-occupied slot.
]=]

--[=[
    @prop INVALID_CATEGORY string
    @within Errors
    Emitted when the item's category does not exist in CategoryConfig.
]=]

--[=[
    @prop INVALID_TRANSFER string
    @within Errors
    Emitted when a transfer cannot be completed (e.g. source equals destination).
]=]

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
