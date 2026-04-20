--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ItemConfig = require(ReplicatedStorage.Contexts.Inventory.Config.ItemConfig)
local CategoryConfig = require(ReplicatedStorage.Contexts.Inventory.Config.CategoryConfig)

--[=[
    @class ItemStackingService
    Pure domain service for evaluating and computing item stacking behaviour.
    @server
]=]
local ItemStackingService = {}
ItemStackingService.__index = ItemStackingService

--[=[
    Create a new ItemStackingService with no dependencies.
    @within ItemStackingService
    @return ItemStackingService
]=]
function ItemStackingService.new()
	local self = setmetatable({}, ItemStackingService)
	return self
end

--[=[
    Check whether two items are the same and have the stackable flag set.
    @within ItemStackingService
    @param itemId1 string -- First item ID
    @param itemId2 string -- Second item ID
    @return boolean -- True if both IDs match and the item is stackable
]=]
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

--[=[
    Calculate how many more items can be added to the given slot before it reaches its stack cap.
    @within ItemStackingService
    @param slot any -- The slot data table (must have `ItemId`, `Category`, and `Quantity`)
    @return number -- Available space (0 if item or category config is missing)
]=]
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

--[=[
    Return the indices of all occupied slots that contain the given item and still have available stack space.
    @within ItemStackingService
    @param inventoryState any -- The current inventory state (must have a `Slots` table)
    @param itemId string -- The item ID to search for
    @return {number} -- Slot indices with available space; empty if the item is not stackable
]=]
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

--[=[
    Sum the total quantity of the given item across all inventory slots.
    @within ItemStackingService
    @param inventoryState any -- The current inventory state
    @param itemId string -- The item ID to total
    @return number -- Combined quantity across all slots
]=]
function ItemStackingService:GetTotalQuantity(inventoryState: any, itemId: string): number
	local totalQuantity = 0

	for _, slot in pairs(inventoryState.Slots) do
		if slot.ItemId == itemId then
			totalQuantity = totalQuantity + slot.Quantity
		end
	end

	return totalQuantity
end

--[=[
    Calculate the minimum number of slots required to hold the given quantity of an item.
    @within ItemStackingService
    @param itemId string -- The item ID (used to look up maxStack)
    @param quantity number -- The total quantity to store
    @return number -- Number of slots needed; 0 if the item does not exist in ItemConfig
]=]
function ItemStackingService:CalculateSlotsNeeded(itemId: string, quantity: number): number
	local itemData = ItemConfig[itemId]
	if not itemData then
		return 0
	end

	local maxStack = itemData.maxStack
	return math.ceil(quantity / maxStack)
end

return ItemStackingService
