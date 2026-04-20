--!strict

--[=[
	@class Errors
	Error message constants for guild operations.
	@server
]=]
return table.freeze({
	PLAYER_NOT_FOUND = "Player not found",
	INVALID_ADVENTURER_TYPE = "Adventurer type does not exist",
	ROSTER_FULL = "Adventurer roster is full",
	INSUFFICIENT_GOLD = "Not enough gold to hire",
	ADVENTURER_NOT_FOUND = "Adventurer not found in roster",
	INVALID_SLOT_TYPE = "Invalid equipment slot type",
	ITEM_NOT_EQUIPPABLE = "Item cannot be equipped in this slot",
	SLOT_ALREADY_EMPTY = "Equipment slot is already empty",
	ITEM_NOT_IN_INVENTORY = "Item not found in inventory",
	INVENTORY_FULL = "Inventory is full, cannot unequip",
	HIRE_FAILED = "Hiring failed unexpectedly",
	EQUIP_FAILED = "Equipping failed unexpectedly",
	UNEQUIP_FAILED = "Unequipping failed unexpectedly",
})
