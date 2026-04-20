--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ItemConfig = require(ReplicatedStorage.Contexts.Inventory.Config.ItemConfig)
local CategoryConfig = require(ReplicatedStorage.Contexts.Inventory.Config.CategoryConfig)

local InventorySlot = {}
InventorySlot.__index = InventorySlot

--- Creates and validates an InventorySlot value object
-- Ensures itemId, quantity, and slotIndex are all valid
function InventorySlot.new(itemId: string, quantity: number, slotIndex: number)
	assert(type(itemId) == "string" and #itemId > 0, "ItemId must be non-empty string")
	assert(type(quantity) == "number" and quantity > 0, "Quantity must be positive")
	assert(type(slotIndex) == "number" and slotIndex > 0, "SlotIndex must be positive")

	-- Validate item exists
	local itemData = ItemConfig[itemId]
	assert(itemData, "Item with id '" .. itemId .. "' not found in ItemConfig")

	-- Validate quantity doesn't exceed maxStack
	assert(quantity <= itemData.maxStack, "Quantity (" .. quantity .. ") exceeds maxStack (" .. itemData.maxStack .. ")")

	local self = setmetatable({}, InventorySlot)
	self.ItemId = itemId
	self.Quantity = quantity
	self.SlotIndex = slotIndex
	self.Category = itemData.category

	return self
end

--- Gets the item ID
function InventorySlot:GetItemId(): string
	return self.ItemId
end

--- Gets the quantity
function InventorySlot:GetQuantity(): number
	return self.Quantity
end

--- Gets the slot index
function InventorySlot:GetSlotIndex(): number
	return self.SlotIndex
end

--- Gets the category
function InventorySlot:GetCategory(): string
	return self.Category
end

--- Checks if this slot is at max capacity for its item
function InventorySlot:IsAtCapacity(): boolean
	local itemData = ItemConfig[self.ItemId]
	local categoryConfig = CategoryConfig[self.Category]
	local maxStack = math.min(itemData.maxStack, categoryConfig.maxStack)
	return self.Quantity >= maxStack
end

return InventorySlot
