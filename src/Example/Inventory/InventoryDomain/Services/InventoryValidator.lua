--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ItemConfig = require(ReplicatedStorage.Contexts.Inventory.Config.ItemConfig)
local CategoryConfig = require(ReplicatedStorage.Contexts.Inventory.Config.CategoryConfig)
local Errors = require(script.Parent.Parent.Parent.Errors)

local InventoryValidator = {}
InventoryValidator.__index = InventoryValidator

--- Creates a new InventoryValidator (no dependencies - pure domain logic)
function InventoryValidator.new()
	local self = setmetatable({}, InventoryValidator)
	return self
end

--- Validates that an item can be added to inventory
-- Returns (success: boolean, errors: { string })
function InventoryValidator:ValidateAddItem(
	inventoryState: any,
	itemId: string,
	quantity: number
): (boolean, { string })
	local errors = {}

	-- Validate item exists
	if not ItemConfig[itemId] then
		table.insert(errors, Errors.INVALID_ITEM_ID)
		return false, errors
	end

	local itemData = ItemConfig[itemId]
	local categoryConfig = CategoryConfig[itemData.category]

	-- Validate quantity
	if quantity < 1 then
		table.insert(errors, Errors.INVALID_QUANTITY)
		return false, errors
	end

	local maxStack = math.min(itemData.maxStack, categoryConfig.maxStack)
	if quantity > maxStack then
		table.insert(errors, Errors.INVALID_QUANTITY)
		return false, errors
	end

	-- Check total inventory capacity
	local usedSlots = inventoryState.Metadata.UsedSlots or 0
	if usedSlots >= inventoryState.Metadata.TotalSlots then
		table.insert(errors, Errors.INVENTORY_FULL)
		return false, errors
	end

	-- Check category capacity
	local categoryUsed = self:_GetCategoryUsage(inventoryState, itemData.category)
	if categoryUsed >= categoryConfig.totalCapacity then
		table.insert(errors, Errors.CATEGORY_FULL)
		return false, errors
	end

	return #errors == 0, errors
end

--- Validates that an item can be removed from a slot
-- Returns (success: boolean, errors: { string })
function InventoryValidator:ValidateRemoveItem(
	inventoryState: any,
	slotIndex: number,
	quantity: number
): (boolean, { string })
	local errors = {}

	-- Validate slot index
	if slotIndex < 1 or slotIndex > inventoryState.Metadata.TotalSlots then
		table.insert(errors, Errors.INVALID_SLOT_INDEX)
		return false, errors
	end

	-- Check slot exists
	local slot = inventoryState.Slots[slotIndex]
	if not slot then
		table.insert(errors, Errors.SLOT_EMPTY)
		return false, errors
	end

	-- Validate quantity
	if quantity < 1 then
		table.insert(errors, Errors.INVALID_QUANTITY)
		return false, errors
	end

	if quantity > slot.Quantity then
		table.insert(errors, Errors.INSUFFICIENT_QUANTITY)
		return false, errors
	end

	return #errors == 0, errors
end

--- Validates that an item can be transferred between slots
-- Returns (success: boolean, errors: { string })
function InventoryValidator:ValidateTransferItem(
	inventoryState: any,
	fromSlotIndex: number,
	toSlotIndex: number
): (boolean, { string })
	local errors = {}

	-- Validate source slot
	if fromSlotIndex < 1 or fromSlotIndex > inventoryState.Metadata.TotalSlots then
		table.insert(errors, Errors.INVALID_SLOT_INDEX)
		return false, errors
	end

	local fromSlot = inventoryState.Slots[fromSlotIndex]
	if not fromSlot then
		table.insert(errors, Errors.SLOT_EMPTY)
		return false, errors
	end

	-- Validate destination slot index
	if toSlotIndex < 1 or toSlotIndex > inventoryState.Metadata.TotalSlots then
		table.insert(errors, Errors.INVALID_SLOT_INDEX)
		return false, errors
	end

	return #errors == 0, errors
end

--- Helper: Gets usage count for a specific category
function InventoryValidator:_GetCategoryUsage(inventoryState: any, category: string): number
	local count = 0

	for _, slot in pairs(inventoryState.Slots) do
		if slot.Category == category then
			count = count + 1
		end
	end

	return count
end

return InventoryValidator
