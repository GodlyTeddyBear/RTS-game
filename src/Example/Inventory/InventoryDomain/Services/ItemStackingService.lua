--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ItemConfig = require(ReplicatedStorage.Contexts.Inventory.Config.ItemConfig)
local CategoryConfig = require(ReplicatedStorage.Contexts.Inventory.Config.CategoryConfig)

local ItemStackingService = {}
ItemStackingService.__index = ItemStackingService

--- Creates a new ItemStackingService (no dependencies - pure domain logic)
function ItemStackingService.new()
	local self = setmetatable({}, ItemStackingService)
	return self
end

--- Checks if two items can stack together
function ItemStackingService:CanStack(itemId1: string, itemId2: string): boolean
	-- Must be same item
	if itemId1 ~= itemId2 then
		return false
	end

	-- Item must be stackable
	local itemData = ItemConfig[itemId1]
	if not itemData or not itemData.stackable then
		return false
	end

	return true
end

--- Gets available stack space in a slot
function ItemStackingService:GetAvailableStackSpace(slot: any): number
	local itemData = ItemConfig[slot.ItemId]
	if not itemData then
		return 0
	end

	local categoryConfig = CategoryConfig[slot.Category]
	if not categoryConfig then
		return 0
	end

	local maxStack = math.min(itemData.maxStack, categoryConfig.maxStack)
	local availableSpace = maxStack - slot.Quantity

	return math.max(0, availableSpace)
end

--- Finds all stackable slots for a given item
function ItemStackingService:FindStackableSlots(inventoryState: any, itemId: string): { number }
	local stackableSlots = {}

	if not ItemConfig[itemId] or not ItemConfig[itemId].stackable then
		return stackableSlots
	end

	for slotIndex, slot in pairs(inventoryState.Slots) do
		if slot.ItemId == itemId then
			local availableSpace = self:GetAvailableStackSpace(slot)
			if availableSpace > 0 then
				table.insert(stackableSlots, slotIndex)
			end
		end
	end

	return stackableSlots
end

--- Calculates the total quantity of an item across all slots
function ItemStackingService:GetTotalQuantity(inventoryState: any, itemId: string): number
	local totalQuantity = 0

	for _, slot in pairs(inventoryState.Slots) do
		if slot.ItemId == itemId then
			totalQuantity = totalQuantity + slot.Quantity
		end
	end

	return totalQuantity
end

--- Calculates how many slots would be needed to store a quantity of items
function ItemStackingService:CalculateSlotsNeeded(itemId: string, quantity: number): number
	local itemData = ItemConfig[itemId]
	if not itemData then
		return 0
	end

	local maxStack = itemData.maxStack
	return math.ceil(quantity / maxStack)
end

return ItemStackingService
