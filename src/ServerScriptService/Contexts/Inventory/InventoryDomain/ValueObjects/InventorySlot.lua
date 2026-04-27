--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ItemConfig = require(ReplicatedStorage.Contexts.Inventory.Config.ItemConfig)

--[=[
    @class InventorySlot
    Immutable value object representing a single occupied inventory slot.
    @server
]=]
local InventorySlot = {}
InventorySlot.__index = InventorySlot

--[=[
    Create and validate an InventorySlot, asserting that the item exists and quantity is within stack limits.
    @within InventorySlot
    @param itemId string -- The item ID (must exist in ItemConfig)
    @param quantity number -- Item count (must be between 1 and item's maxStack)
    @param slotIndex number -- 1-based slot position in the inventory
    @return InventorySlot -- The validated slot value object
    @error string -- Thrown if itemId, quantity, or slotIndex are invalid
]=]
function InventorySlot.new(itemId: string, quantity: number, slotIndex: number)
	assert(type(itemId) == "string" and #itemId > 0, "ItemId must be non-empty string")
	assert(type(quantity) == "number" and quantity > 0, "Quantity must be positive")
	assert(type(slotIndex) == "number" and slotIndex > 0, "SlotIndex must be positive")

	-- Validate item exists
	local itemData = ItemConfig[itemId]
	assert(itemData, "Item with id '" .. itemId .. "' not found in ItemConfig")

	-- Validate quantity doesn't exceed maxStack
	assert(quantity <= itemData.MaxStack, "Quantity (" .. quantity .. ") exceeds maxStack (" .. itemData.MaxStack .. ")")

	local self = setmetatable({}, InventorySlot)
	self.ItemId = itemId
	self.Quantity = quantity
	self.SlotIndex = slotIndex
	self.Category = itemData.Category

	return table.freeze(self)
end

--[=[
    Return the item ID stored in this slot.
    @within InventorySlot
    @return string -- The item ID
]=]
function InventorySlot:GetItemId(): string
	return self.ItemId
end

--[=[
    Return the item quantity stored in this slot.
    @within InventorySlot
    @return number -- The quantity
]=]
function InventorySlot:GetQuantity(): number
	return self.Quantity
end

--[=[
    Return the 1-based slot position in the inventory.
    @within InventorySlot
    @return number -- The slot index
]=]
function InventorySlot:GetSlotIndex(): number
	return self.SlotIndex
end

--[=[
    Return the item category for this slot.
    @within InventorySlot
    @return string -- The category name
]=]
function InventorySlot:GetCategory(): string
	return self.Category
end

--[=[
    Check whether this slot has reached its effective maximum stack size.
    @within InventorySlot
    @return boolean -- True if the slot cannot accept more of this item
]=]
function InventorySlot:IsAtCapacity(): boolean
	local itemData = ItemConfig[self.ItemId]
	return self.Quantity >= itemData.MaxStack
end

return InventorySlot
