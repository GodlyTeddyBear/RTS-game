--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local BaseSyncService = require(ReplicatedStorage.Utilities.BaseSyncService)
local SharedAtoms = require(ReplicatedStorage.Contexts.Inventory.Sync.SharedAtoms)

--[[
	Inventory Sync Service

	Manages inventory state synchronization. Extends BaseSyncService for
	CharmSync + Blink wiring; defines only inventory-specific mutations.

	IMPORTANT: All inventory atom mutations are centralized in this service.
]]

--[=[
    @class InventorySyncService
    Infrastructure service that manages inventory atom state and all centralized mutations for sync.
    @server
]=]
local InventorySyncService = setmetatable({}, { __index = BaseSyncService })
InventorySyncService.__index = InventorySyncService
InventorySyncService.AtomKey = "inventories"
InventorySyncService.BlinkEventName = "SyncInventory"
InventorySyncService.CreateAtom = SharedAtoms.CreateServerAtom

--[=[
    Create a new InventorySyncService instance.
    @within InventorySyncService
    @return InventorySyncService
]=]
function InventorySyncService.new()
	return setmetatable({}, InventorySyncService)
end

--[[
	READ-ONLY GETTERS
]]

--[=[
    Return a deep clone of the player's inventory for safe read-only access.
    @within InventorySyncService
    @param userId number -- The player's UserId
    @return any? -- A deep clone of the inventory state, or nil if not found
]=]
function InventorySyncService:GetInventoryReadOnly(userId: number)
	return self:GetReadOnly(userId)
end

--[=[
    Return the server-side Charm atom holding all player inventories.
    @within InventorySyncService
    @return any -- The inventories atom
]=]
function InventorySyncService:GetInventoriesAtom()
	return self:GetAtom()
end

--[[
	CENTRALIZED MUTATION METHODS
]]

--[=[
    Initialize a fresh inventory atom entry for a new player.
    @within InventorySyncService
    @param userId number -- The player's UserId
    @param maxCapacity number -- Total slot capacity for the new inventory
]=]
function InventorySyncService:CreateInventory(userId: number, maxCapacity: number)
	-- Create fresh inventory entry in atom for new player; called during join if no saved data exists
	self.Atom(function(current)
		local updated = table.clone(current)
		updated[userId] = {
			Slots = {},
			Metadata = {
				TotalSlots = maxCapacity,
				UsedSlots = 0,
				LastModified = 0,
			},
		}
		return updated
	end)
end

--[=[
    Remove a player's inventory entry from the atom.
    @within InventorySyncService
    @param userId number -- The player's UserId
]=]
function InventorySyncService:RemoveInventory(userId: number)
	self:RemoveUserData(userId)
end

--[=[
    Add an item to a player's inventory atom, increasing quantity if the target slot is occupied.
    @within InventorySyncService
    @param userId number -- The player's UserId
    @param itemId string -- The item ID to add
    @param quantity number -- How many to add
    @param slotIndex number? -- Optional target slot; if nil, the first empty slot is used
]=]
function InventorySyncService:AddItem(userId: number, itemId: string, quantity: number, slotIndex: number?)
	self.Atom(function(current)
		local updated = table.clone(current)
		if not updated[userId] then
			return updated
		end

		updated[userId] = table.clone(updated[userId])
		updated[userId].Items = table.clone(updated[userId].Items)

		local targetSlot = slotIndex or self:_FindEmptySlot(updated[userId])
		if not targetSlot then
			return updated
		end

		if updated[userId].Items[targetSlot] then
			updated[userId].Items[targetSlot] = table.clone(updated[userId].Items[targetSlot])
			updated[userId].Items[targetSlot].quantity += quantity
		else
			updated[userId].Items[targetSlot] = table.freeze({
				itemId = itemId,
				quantity = quantity,
				slotIndex = targetSlot,
			})
			updated[userId].Capacity += 1
		end

		return updated
	end)
end

--[=[
    Remove items from a slot in the atom, clearing the slot entirely if quantity meets or exceeds contents.
    @within InventorySyncService
    @param userId number -- The player's UserId
    @param slotIndex number -- The slot to remove from
    @param quantity number -- How many to remove
]=]
function InventorySyncService:RemoveItem(userId: number, slotIndex: number, quantity: number)
	self.Atom(function(current)
		local updated = table.clone(current)
		if not updated[userId] then
			return updated
		end

		updated[userId] = table.clone(updated[userId])
		updated[userId].Items = table.clone(updated[userId].Items)

		local item = updated[userId].Items[slotIndex]
		if not item then
			return updated
		end

		if item.quantity <= quantity then
			updated[userId].Items[slotIndex] = nil
			updated[userId].Capacity -= 1
		else
			updated[userId].Items[slotIndex] = table.clone(item)
			updated[userId].Items[slotIndex].quantity = item.quantity - quantity
		end

		return updated
	end)
end

--[=[
    Set the quantity of an existing slot directly; removes the slot if quantity is zero or less.
    @within InventorySyncService
    @param userId number -- The player's UserId
    @param slotIndex number -- The slot to update
    @param quantity number -- The new quantity (<=0 removes the slot)
]=]
function InventorySyncService:SetItemQuantity(userId: number, slotIndex: number, quantity: number)
	self.Atom(function(current)
		local updated = table.clone(current)
		if not updated[userId] then
			return updated
		end

		updated[userId] = table.clone(updated[userId])
		updated[userId].Items = table.clone(updated[userId].Items)

		local item = updated[userId].Items[slotIndex]
		if not item then
			return updated
		end

		if quantity <= 0 then
			updated[userId].Items[slotIndex] = nil
			updated[userId].Capacity -= 1
		else
			updated[userId].Items[slotIndex] = table.clone(item)
			updated[userId].Items[slotIndex].quantity = quantity
		end

		return updated
	end)
end

--[=[
    Write slot data to the given index, or clear the slot if `slotData` is nil.
    @within InventorySyncService
    @param userId number -- The player's UserId
    @param slotIndex number -- The slot index to write
    @param slotData any? -- The slot data to set, or nil to clear
]=]
function InventorySyncService:SetSlot(userId: number, slotIndex: number, slotData: any?)
	self.Atom(function(current)
		local updated = table.clone(current)
		if not updated[userId] then
			return updated
		end

		updated[userId] = table.clone(updated[userId])
		updated[userId].Slots = table.clone(updated[userId].Slots)
		updated[userId].Slots[slotIndex] = slotData
		return updated
	end)
end

--[=[
    Update the `Quantity` field of an existing slot; removes the slot if `newQuantity` is zero or less.
    @within InventorySyncService
    @param userId number -- The player's UserId
    @param slotIndex number -- The slot to update
    @param newQuantity number -- The new quantity (<=0 removes the slot)
]=]
function InventorySyncService:UpdateSlotQuantity(userId: number, slotIndex: number, newQuantity: number)
	-- Update quantity of existing slot; removes slot entirely if newQuantity <= 0
	self.Atom(function(current)
		local updated = table.clone(current)
		if not updated[userId] then
			return updated
		end

		updated[userId] = table.clone(updated[userId])
		updated[userId].Slots = table.clone(updated[userId].Slots)

		local slot = updated[userId].Slots[slotIndex]
		if not slot then
			return updated
		end

		-- Clear slot if quantity exhausted; otherwise clone and update quantity value
		if newQuantity <= 0 then
			updated[userId].Slots[slotIndex] = nil
		else
			updated[userId].Slots[slotIndex] = table.clone(slot)
			updated[userId].Slots[slotIndex].Quantity = newQuantity
		end

		return updated
	end)
end

--[=[
    Exchange the contents of two slots, updating each slot's `SlotIndex` field.
    @within InventorySyncService
    @param userId number -- The player's UserId
    @param fromSlot number -- First slot index
    @param toSlot number -- Second slot index
]=]
function InventorySyncService:SwapSlots(userId: number, fromSlot: number, toSlot: number)
	-- Exchange slot contents and update each slot's SlotIndex field to match its new position
	self.Atom(function(current)
		local updated = table.clone(current)
		if not updated[userId] then
			return updated
		end

		updated[userId] = table.clone(updated[userId])
		updated[userId].Slots = table.clone(updated[userId].Slots)

		local fromData = updated[userId].Slots[fromSlot]
		local toData = updated[userId].Slots[toSlot]

		-- Swap contents
		updated[userId].Slots[fromSlot] = toData
		updated[userId].Slots[toSlot] = fromData

		-- Update SlotIndex in each slot to match its new position (must clone to avoid shared references)
		if updated[userId].Slots[fromSlot] then
			updated[userId].Slots[fromSlot] = table.clone(updated[userId].Slots[fromSlot])
			updated[userId].Slots[fromSlot].SlotIndex = fromSlot
		end
		if updated[userId].Slots[toSlot] then
			updated[userId].Slots[toSlot] = table.clone(updated[userId].Slots[toSlot])
			updated[userId].Slots[toSlot].SlotIndex = toSlot
		end

		return updated
	end)
end

--[=[
    Move an item from one slot to another empty slot, clearing the source slot.
    @within InventorySyncService
    @param userId number -- The player's UserId
    @param fromSlot number -- Source slot index
    @param toSlot number -- Destination slot index (must be empty)
]=]
function InventorySyncService:MoveSlot(userId: number, fromSlot: number, toSlot: number)
	-- Move an item to a destination slot (presumed empty); clears source slot
	self.Atom(function(current)
		local updated = table.clone(current)
		if not updated[userId] then
			return updated
		end

		updated[userId] = table.clone(updated[userId])
		updated[userId].Slots = table.clone(updated[userId].Slots)

		local fromData = updated[userId].Slots[fromSlot]
		if not fromData then
			return updated
		end

		-- Clone and update SlotIndex to destination; clear source
		local movedItem = table.clone(fromData)
		movedItem.SlotIndex = toSlot
		updated[userId].Slots[toSlot] = movedItem
		updated[userId].Slots[fromSlot] = nil

		return updated
	end)
end

--[=[
    Remove all slots from a player's inventory, leaving metadata intact.
    @within InventorySyncService
    @param userId number -- The player's UserId
]=]
function InventorySyncService:ClearAllSlots(userId: number)
	self.Atom(function(current)
		local updated = table.clone(current)
		if not updated[userId] then
			return updated
		end

		updated[userId] = table.clone(updated[userId])
		updated[userId].Slots = {}
		return updated
	end)
end

--[=[
    Merge the given key-value pairs into the player's inventory `Metadata` table.
    @within InventorySyncService
    @param userId number -- The player's UserId
    @param metadata {[string]: any} -- Fields to update (e.g. `UsedSlots`, `LastModified`)
]=]
function InventorySyncService:UpdateMetadata(userId: number, metadata: { [string]: any })
	-- Merge key-value pairs into Metadata table (e.g., UsedSlots, LastModified)
	self.Atom(function(current)
		local updated = table.clone(current)
		if not updated[userId] then
			return updated
		end

		updated[userId] = table.clone(updated[userId])
		updated[userId].Metadata = table.clone(updated[userId].Metadata)

		-- Shallow merge; caller responsible for value types
		for key, value in pairs(metadata) do
			updated[userId].Metadata[key] = value
		end

		return updated
	end)
end

--- Helper: Find first empty slot
function InventorySyncService:_FindEmptySlot(inventory): number?
	for i = 1, inventory.MaxCapacity do
		if not inventory.Items[i] then
			return i
		end
	end
	return nil
end

return InventorySyncService
