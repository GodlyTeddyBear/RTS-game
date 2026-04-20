--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ItemConfig = require(ReplicatedStorage.Contexts.Inventory.Config.ItemConfig)
local Result = require(ReplicatedStorage.Utilities.Result)
local MentionSuccess = Result.MentionSuccess

local PersistInventory = require(script.Parent.Parent.PersistInventory)

local Ok = Result.Ok
local Try = Result.Try
local Ensure = Result.Ensure
local fromNilable = Result.fromNilable

--[=[
    @class StackItems
    Application command that consolidates all slots of the same item into the fewest possible slots.
    @server
]=]
local StackItems = {}
StackItems.__index = StackItems

--[=[
    Create a new StackItems instance (zero-arg for Registry).
    @within StackItems
    @return StackItems
]=]
function StackItems.new()
	local self = setmetatable({}, StackItems)
	return self
end

--- Pulls dependencies from the Registry
function StackItems:Init(registry: any, _name: string)
	self.StackItemsPolicy = registry:Get("StackItemsPolicy")
	self.StackingService = registry:Get("ItemStackingService")
	self.SyncService = registry:Get("InventorySyncService")
	self.PersistenceService = registry:Get("InventoryPersistenceService")
end

--[=[
    Consolidate all slots containing the given item into the fewest possible slots and persist the result.
    @within StackItems
    @param player Player -- The player whose inventory is consolidated
    @param userId number -- The player's UserId
    @param itemId string -- The item ID to consolidate
    @return Result<any> -- Ok with slots consolidated count and final slot count; Err if validation fails
]=]
function StackItems:Execute(player: Player, userId: number, itemId: string): Result.Result<any>
	Ensure(player ~= nil and userId > 0, "InvalidArgument", "Invalid player or userId")
	Try(self.StackItemsPolicy:Check(itemId))
	MentionSuccess("Inventory:StackItems:Validation", "userId: " .. userId .. " - Validation passed for stacking " .. itemId)

	local playerInventory = Try(self:_GetInventory(userId))
	local itemSlots = self:_FindSlotsForItem(playerInventory, itemId)

	-- Early exit: stacking only meaningful when item occupies 2+ slots
	if #itemSlots <= 1 then
		MentionSuccess("Inventory:StackItems:Stacking", "userId: " .. userId .. " - No stacking needed for " .. itemId)
		return Ok({ Message = "No stacking needed", SlotsConsolidated = 0 })
	end

	-- Collect total quantity and create working copy with old slots cleared
	local totalQuantity = self:_SumQuantity(playerInventory, itemSlots)
	local inventoryCopy = self:_BuildCleanedCopy(playerInventory, itemSlots)

	-- Redistribute total quantity into fewest possible slots respecting maxStack
	local slotsToSet = Try(self:_DistributeIntoSlots(inventoryCopy, itemId, totalQuantity, userId))

	-- Clear old slots and set new consolidated slots; update metadata
	self:_ApplyChanges(userId, itemSlots, slotsToSet, inventoryCopy)

	-- Report consolidation result
	local slotsConsolidated = #itemSlots - self:_CountEntries(slotsToSet)
	MentionSuccess("Inventory:StackItems:Stacking", "userId: " .. userId .. " - Consolidated " .. slotsConsolidated .. " slots for " .. itemId)

	PersistInventory(self.SyncService, self.PersistenceService, player, userId)
	MentionSuccess("Inventory:StackItems:Persistence", "userId: " .. userId .. " - Inventory persisted successfully")

	return Ok({
		Message = "Items stacked successfully",
		SlotsConsolidated = slotsConsolidated,
		FinalSlots = self:_CountEntries(slotsToSet),
		TotalQuantity = totalQuantity,
	})
end

function StackItems:_GetInventory(userId: number): Result.Result<any>
	return fromNilable(self.SyncService:GetInventoryReadOnly(userId), "InventoryNotFound", "Inventory not found", { userId = userId })
end

function StackItems:_FindSlotsForItem(playerInventory: any, itemId: string): { number }
	local itemSlots = {}
	for slotIndex, slot in pairs(playerInventory.Slots) do
		if slot.ItemId == itemId then
			table.insert(itemSlots, slotIndex)
		end
	end
	return itemSlots
end

function StackItems:_SumQuantity(playerInventory: any, itemSlots: { number }): number
	local total = 0
	for _, slotIndex in ipairs(itemSlots) do
		total = total + playerInventory.Slots[slotIndex].Quantity
	end
	return total
end

function StackItems:_BuildCleanedCopy(playerInventory: any, itemSlots: { number }): any
	-- Create working copy with target item slots cleared; leaves other items intact
	local copy = {
		Slots = table.clone(playerInventory.Slots),
		Metadata = playerInventory.Metadata,
	}

	-- Remove all instances of the item being consolidated so they can be re-distributed optimally
	for _, slotIndex in ipairs(itemSlots) do
		copy.Slots[slotIndex] = nil
	end
	return copy
end

function StackItems:_DistributeIntoSlots(inventoryCopy: any, itemId: string, totalQuantity: number, userId: number): Result.Result<any>
	-- Distribute total quantity into fewest possible slots respecting maxStack limit
	local itemData = ItemConfig[itemId]
	local maxStack = itemData.maxStack
	local remaining = totalQuantity
	local slotsToSet: { [number]: any } = {}

	-- Fill slots up to maxStack; each loop iteration creates one packed slot
	while remaining > 0 do
		local availableSlot = self:_FindAvailableSlotForItem(inventoryCopy, itemId)
		Ensure(availableSlot, "InventoryFull", "Not enough inventory space to consolidate items", { itemId = itemId, userId = userId })

		-- Add up to maxStack or remaining quantity to this slot
		local toAdd = math.min(remaining, maxStack)
		local slotData = {
			SlotIndex = availableSlot,
			ItemId = itemId,
			Quantity = toAdd,
			Category = itemData.category,
		}
		slotsToSet[availableSlot] = slotData
		inventoryCopy.Slots[availableSlot] = slotData
		remaining = remaining - toAdd
	end

	return Ok(slotsToSet)
end

function StackItems:_ApplyChanges(userId: number, oldSlots: { number }, newSlots: { [number]: any }, inventoryCopy: any)
	-- Clear all old slots that held the target item
	for _, slotIndex in ipairs(oldSlots) do
		self.SyncService:SetSlot(userId, slotIndex, nil)
	end

	-- Set new consolidated slots with packed quantities
	for slotIndex, slotData in pairs(newSlots) do
		self.SyncService:SetSlot(userId, slotIndex, slotData)
	end

	-- Update metadata with final used slot count; old and new slots accounted for in inventoryCopy
	self.SyncService:UpdateMetadata(userId, {
		UsedSlots = self:_CountUsedSlots(inventoryCopy),
		LastModified = os.time(),
	})
end

function StackItems:_FindAvailableSlotForItem(inventoryState: any, itemId: string): number?
	local maxStack = ItemConfig[itemId].maxStack

	-- Priority 1: Find existing slot with same item that has room to stack
	for slotIndex, slot in pairs(inventoryState.Slots) do
		if slot.ItemId == itemId and slot.Quantity < maxStack then
			return slotIndex
		end
	end

	-- Priority 2: Find first empty slot for new item (only reached if no existing stacks have room)
	for slotIndex = 1, inventoryState.Metadata.TotalSlots do
		if not inventoryState.Slots[slotIndex] then
			return slotIndex
		end
	end

	-- Inventory full; caller must handle (Ensure in _DistributeIntoSlots)
	return nil
end

function StackItems:_CountUsedSlots(inventoryState: any): number
	local count = 0
	for _ in pairs(inventoryState.Slots) do
		count = count + 1
	end
	return count
end

function StackItems:_CountEntries(tbl: { [number]: any }): number
	local count = 0
	for _ in pairs(tbl) do
		count = count + 1
	end
	return count
end

return StackItems
