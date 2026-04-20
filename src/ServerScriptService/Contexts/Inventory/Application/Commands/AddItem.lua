--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ItemConfig = require(ReplicatedStorage.Contexts.Inventory.Config.ItemConfig)
local Errors = require(script.Parent.Parent.Parent.Errors)
local Result = require(ReplicatedStorage.Utilities.Result)
local MentionSuccess = Result.MentionSuccess

local PersistInventory = require(script.Parent.Parent.PersistInventory)

local Ok = Result.Ok
local Err = Result.Err
local Try = Result.Try
local Ensure = Result.Ensure

--[=[
    @class AddItem
    Application command that adds items to a player's inventory, stacking onto existing slots where possible.
    @server
]=]
local AddItem = {}
AddItem.__index = AddItem

--[=[
    Create a new AddItem instance (zero-arg for Registry).
    @within AddItem
    @return AddItem
]=]
function AddItem.new()
	local self = setmetatable({}, AddItem)
	return self
end

--- Pulls dependencies from the Registry
function AddItem:Init(registry: any, _name: string)
	self.AddItemPolicy = registry:Get("AddItemPolicy")
	self.StackingService = registry:Get("ItemStackingService")
	self.SlotManagementService = registry:Get("SlotManagementService")
	self.SyncService = registry:Get("InventorySyncService")
	self.PersistenceService = registry:Get("InventoryPersistenceService")
end

--[=[
    Add items to a player's inventory, filling existing stackable slots first, then opening new slots.
    @within AddItem
    @param player Player -- The player receiving the item
    @param userId number -- The player's UserId
    @param itemId string -- The item ID to add (must exist in ItemConfig)
    @param quantity number -- How many items to add
    @return Result<any> -- Ok with added/remaining quantities; Err if validation fails or inventory is full
]=]
function AddItem:Execute(player: Player, userId: number, itemId: string, quantity: number): Result.Result<any>
	Ensure(player ~= nil and userId > 0, "InvalidArgument", "Invalid player or userId")

	local ctx = Try(self.AddItemPolicy:Check(userId, itemId, quantity))
	local playerInventory = ctx.InventoryState
	MentionSuccess("Inventory:AddItem:Validation", "userId: " .. userId .. " - Validation passed for " .. itemId .. " x" .. quantity)

	local updatedSlots, remaining = self:_StackOntoExistingSlots(playerInventory, itemId, quantity)
	local inventoryCopy = self:_BuildWorkingCopy(playerInventory, updatedSlots)
	local newSlots
	newSlots, remaining = self:_FillNewSlots(inventoryCopy, itemId, remaining)

	local addedQuantity = quantity - remaining
	if addedQuantity <= 0 then
		return Err("InventoryFull", Errors.INVENTORY_FULL, { itemId = itemId, userId = userId })
	end

	self:_ApplyChanges(userId, updatedSlots, newSlots, playerInventory.Metadata.UsedSlots)
	MentionSuccess("Inventory:AddItem:SlotManagement", "userId: " .. userId .. " - Added " .. addedQuantity .. " of " .. itemId)

	PersistInventory(self.SyncService, self.PersistenceService, player, userId)
	MentionSuccess("Inventory:AddItem:Persistence", "userId: " .. userId .. " - Inventory persisted successfully")

	return Ok({
		Message = "Item added successfully",
		AddedQuantity = addedQuantity,
		RemainingQuantity = remaining,
	})
end

function AddItem:_StackOntoExistingSlots(playerInventory: any, itemId: string, quantity: number): ({ [number]: number }, number)
	-- Fetch item config and find all existing slots that can stack this item
	local itemData = ItemConfig[itemId]
	local maxStack = math.min(itemData.maxStack, 100)
	local stackableSlots = self.StackingService:FindStackableSlots(playerInventory, itemId)
	local remaining = quantity
	local updatedSlots: { [number]: number } = {}

	-- Fill each stackable slot up to its limit, tracking quantity added per slot
	for _, slotIndex in ipairs(stackableSlots) do
		if remaining <= 0 then
			break
		end

		local slot = playerInventory.Slots[slotIndex]
		local toAdd = math.min(remaining, maxStack - slot.Quantity)
		updatedSlots[slotIndex] = slot.Quantity + toAdd
		remaining = remaining - toAdd
	end

	return updatedSlots, remaining
end

function AddItem:_BuildWorkingCopy(playerInventory: any, updatedSlots: { [number]: number }): any
	-- Create shallow working copy to avoid mutating during slot-filling phase
	local copy = {
		Slots = table.clone(playerInventory.Slots),
		Metadata = playerInventory.Metadata,
	}

	-- Update quantities in affected slots; slot data must be cloned to prevent shared references
	for slotIndex, newQty in pairs(updatedSlots) do
		copy.Slots[slotIndex] = table.clone(copy.Slots[slotIndex])
		copy.Slots[slotIndex].Quantity = newQty
	end
	return copy
end

function AddItem:_FillNewSlots(inventoryCopy: any, itemId: string, remaining: number): ({ [number]: any }, number)
	-- Find and fill new empty slots with remaining items up to maxStack per slot
	local itemData = ItemConfig[itemId]
	local maxStack = math.min(itemData.maxStack, 100)
	local newSlots: { [number]: any } = {}

	while remaining > 0 do
		local availableSlot = self.SlotManagementService:FindAvailableSlot(inventoryCopy)
		if not availableSlot then
			break
		end

		-- Create new slot with item data; fill up to maxStack or remaining quantity
		local toAdd = math.min(remaining, maxStack)
		local slotData = {
			SlotIndex = availableSlot,
			ItemId = itemId,
			Quantity = toAdd,
			Category = itemData.category,
		}
		newSlots[availableSlot] = slotData
		inventoryCopy.Slots[availableSlot] = slotData
		remaining = remaining - toAdd
	end

	return newSlots, remaining
end

function AddItem:_ApplyChanges(userId: number, updatedSlots: { [number]: number }, newSlots: { [number]: any }, previousUsedSlots: number)
	-- Apply quantity updates to existing stackable slots
	for slotIndex, newQty in pairs(updatedSlots) do
		self.SyncService:UpdateSlotQuantity(userId, slotIndex, newQty)
	end

	-- Apply new slot creations to empty slots
	for slotIndex, slotData in pairs(newSlots) do
		self.SyncService:SetSlot(userId, slotIndex, slotData)
	end

	-- Update metadata with new used slot count; all mutations are atomic at sync layer
	local newSlotsCount = 0
	for _ in pairs(newSlots) do
		newSlotsCount += 1
	end
	self.SyncService:UpdateMetadata(userId, {
		UsedSlots = previousUsedSlots + newSlotsCount,
		LastModified = os.time(),
	})
end

return AddItem
