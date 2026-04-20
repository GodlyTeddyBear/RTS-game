--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ItemConfig = require(ReplicatedStorage.Contexts.Inventory.Config.ItemConfig)
local Errors = require(script.Parent.Parent.Parent.Errors)
local DebugLogger = require(script.Parent.Parent.Parent.Config.DebugLogger)

local StackItems = {}
StackItems.__index = StackItems

--- Creates a new StackItems service
-- Constructor Injection: Receives required dependencies
function StackItems.new(
	inventoryValidator: any,
	stackingService: any,
	playerInventoriesAtom: any,
	persistenceService: any
)
	local self = setmetatable({}, StackItems)

	self.InventoryValidator = inventoryValidator
	self.StackingService = stackingService
	self.PlayerInventoriesAtom = playerInventoriesAtom
	self.PersistenceService = persistenceService
	self.DebugLogger = DebugLogger.new()

	return self
end

--- Executes: Consolidates all slots of the same item into fewer slots
-- Returns (success: boolean, data/error: any)
function StackItems:Execute(player: Player, userId: number, itemId: string): (boolean, any)
	if not player or userId <= 0 then
		warn("[Inventory:StackItems] userId:", userId, "- Invalid player or userId")
		return false, "Invalid player or userId"
	end

	if not itemId or not ItemConfig[itemId] then
		warn("[Inventory:StackItems] userId:", userId, "- Invalid item ID:", itemId)
		return false, Errors.INVALID_ITEM_ID
	end

	local itemData = ItemConfig[itemId]
	if not itemData.stackable then
		warn("[Inventory:StackItems] userId:", userId, "- Item not stackable:", itemId)
		return false, Errors.ITEM_NOT_STACKABLE
	end

	self.DebugLogger:Log("StackItems", "Validation", "userId: " .. userId .. " - Validation passed for stacking " .. itemId)

	-- Get current inventory
	local currentAtom = self.PlayerInventoriesAtom
	local allInventories = currentAtom()
	local playerInventory = allInventories[userId]

	if not playerInventory then
		warn("[Inventory:StackItems] userId:", userId, "- Inventory not found")
		return false, "Inventory not found"
	end

	-- Find all slots with this item
	local itemSlots = {}
	for slotIndex, slot in pairs(playerInventory.Slots) do
		if slot.ItemId == itemId then
			table.insert(itemSlots, slotIndex)
		end
	end

	if #itemSlots <= 1 then
		self.DebugLogger:Log("StackItems", "Stacking", "userId: " .. userId .. " - No stacking needed for " .. itemId)
		return true, {
			Message = "No stacking needed",
			SlotsConsolidated = 0,
		}
	end

	-- Calculate total quantity
	local totalQuantity = 0
	for _, slotIndex in ipairs(itemSlots) do
		totalQuantity = totalQuantity + playerInventory.Slots[slotIndex].Quantity
	end

	-- Remove all item slots
	local maxStack = itemData.maxStack
	for _, slotIndex in ipairs(itemSlots) do
		playerInventory.Slots[slotIndex] = nil
	end

	-- Re-add stacked items
	local remainingQuantity = totalQuantity
	local slotsNeeded = 0

	while remainingQuantity > 0 do
		local availableSlot = self:_FindAvailableSlotForItem(playerInventory, itemId)
		if not availableSlot then
			-- Not enough space to re-add all items
			return false, "Not enough inventory space to consolidate items"
		end

		local toAdd = math.min(remainingQuantity, maxStack)
		playerInventory.Slots[availableSlot] = {
			SlotIndex = availableSlot,
			ItemId = itemId,
			Quantity = toAdd,
			Category = itemData.category,
		}

		remainingQuantity = remainingQuantity - toAdd
		slotsNeeded = slotsNeeded + 1
	end

	-- Update metadata
	playerInventory.Metadata.UsedSlots = self:_CountUsedSlots(playerInventory)
	playerInventory.Metadata.LastModified = os.time()

	-- Update atom atomically
	local success = false
	(currentAtom :: any)(function(current)
		local updated = table.clone(current)
		updated[userId] = playerInventory
		success = true
		return updated
	end)

	if success then
		self.DebugLogger:Log("StackItems", "Stacking", "userId: " .. userId .. " - Consolidated " .. (#itemSlots - slotsNeeded) .. " slots for " .. itemId)

		-- Persist to ProfileStore
		local persistSuccess = self.PersistenceService:SaveInventory(player, playerInventory)
		if not persistSuccess then
			warn("[Inventory:StackItems] userId:", userId, "- Failed to persist inventory")
			return false, "Failed to persist inventory"
		end

		self.DebugLogger:Log("StackItems", "Persistence", "userId: " .. userId .. " - Inventory persisted successfully")

		return true, {
			Message = "Items stacked successfully",
			SlotsConsolidated = #itemSlots - slotsNeeded,
			FinalSlots = slotsNeeded,
			TotalQuantity = totalQuantity,
		}
	end

	warn("[Inventory:StackItems] userId:", userId, "- Failed to update inventory atom")
	return false, "Failed to update inventory atom"
end

--- Helper: Finds next available slot (either empty or with space for item)
function StackItems:_FindAvailableSlotForItem(inventoryState: any, itemId: string): number?
	local maxStack = ItemConfig[itemId].maxStack

	-- First try to find existing slot with space
	for slotIndex, slot in pairs(inventoryState.Slots) do
		if slot.ItemId == itemId and slot.Quantity < maxStack then
			return slotIndex
		end
	end

	-- Then find empty slot
	for slotIndex = 1, inventoryState.Metadata.TotalSlots do
		if not inventoryState.Slots[slotIndex] then
			return slotIndex
		end
	end

	return nil
end

--- Helper: Counts total used slots
function StackItems:_CountUsedSlots(inventoryState: any): number
	local count = 0
	for _ in pairs(inventoryState.Slots) do
		count = count + 1
	end
	return count
end

return StackItems
