--!strict

--[=[
    @class SlotManagementService
    Pure domain service for locating, rearranging, and querying inventory slots.
    @server
]=]
local SlotManagementService = {}
SlotManagementService.__index = SlotManagementService

--[=[
    Create a new SlotManagementService with no dependencies.
    @within SlotManagementService
    @return SlotManagementService
]=]
function SlotManagementService.new()
	local self = setmetatable({}, SlotManagementService)
	return self
end

--[=[
    Find the lowest-index empty slot in the inventory.
    @within SlotManagementService
    @param inventoryState any -- The current inventory state
    @return number? -- The first empty slot index, or nil if the inventory is full
]=]
function SlotManagementService:FindAvailableSlot(inventoryState: any): number?
	local totalSlots = inventoryState.Metadata.TotalSlots

	for slotIndex = 1, totalSlots do
		if not inventoryState.Slots[slotIndex] then
			return slotIndex
		end
	end

	return nil -- No available slots
end

--[=[
    Return the slot data at the given index, or nil if the index is out of range or the slot is empty.
    @within SlotManagementService
    @param inventoryState any -- The current inventory state
    @param slotIndex number -- The slot index to look up
    @return any? -- The slot data table, or nil
]=]
function SlotManagementService:FindSlotByIndex(inventoryState: any, slotIndex: number): any?
	if slotIndex < 1 or slotIndex > inventoryState.Metadata.TotalSlots then
		return nil
	end

	return inventoryState.Slots[slotIndex]
end

--[=[
    Return a sorted list of all occupied slot indices in the inventory.
    @within SlotManagementService
    @param inventoryState any -- The current inventory state
    @return {number} -- Sorted array of occupied slot indices
]=]
function SlotManagementService:GetOccupiedSlots(inventoryState: any): { number }
	local occupied = {}

	for slotIndex in pairs(inventoryState.Slots) do
		table.insert(occupied, slotIndex)
	end

	table.sort(occupied)
	return occupied
end

--[=[
    Return a new inventory state with all items shifted to the lowest available indices, removing gaps.
    @within SlotManagementService
    @param inventoryState any -- The current inventory state
    @return any -- A new inventory state table with compacted slots
]=]
function SlotManagementService:CompactInventory(inventoryState: any): any
	local compacted = {
		Slots = {},
		Metadata = table.clone(inventoryState.Metadata),
	}

	local newSlotIndex = 1
	local occupiedSlots = self:GetOccupiedSlots(inventoryState)

	for _, oldSlotIndex in ipairs(occupiedSlots) do
		local slot = table.clone(inventoryState.Slots[oldSlotIndex])
		slot.SlotIndex = newSlotIndex
		compacted.Slots[newSlotIndex] = slot
		newSlotIndex = newSlotIndex + 1
	end

	return compacted
end

--[=[
    Return a new inventory state with the contents of two slots exchanged.
    @within SlotManagementService
    @param inventoryState any -- The current inventory state
    @param slotIndex1 number -- First slot index
    @param slotIndex2 number -- Second slot index
    @return any -- A new inventory state table with the slots swapped
]=]
function SlotManagementService:SwapSlots(inventoryState: any, slotIndex1: number, slotIndex2: number): any
	local modified = {
		Slots = table.clone(inventoryState.Slots),
		Metadata = table.clone(inventoryState.Metadata),
	}

	local temp = modified.Slots[slotIndex1]
	modified.Slots[slotIndex1] = modified.Slots[slotIndex2]
	modified.Slots[slotIndex2] = temp

	-- Update slot indices
	if modified.Slots[slotIndex1] then
		modified.Slots[slotIndex1].SlotIndex = slotIndex1
	end
	if modified.Slots[slotIndex2] then
		modified.Slots[slotIndex2].SlotIndex = slotIndex2
	end

	return modified
end

--[=[
    Return the indices of the next `count` empty slots in the inventory.
    @within SlotManagementService
    @param inventoryState any -- The current inventory state
    @param count number -- How many empty slots to find
    @return {number} -- Array of empty slot indices (may be shorter than `count` if inventory is full)
]=]
function SlotManagementService:FindMultipleAvailableSlots(inventoryState: any, count: number): { number }
	local available = {}

	for slotIndex = 1, inventoryState.Metadata.TotalSlots do
		if not inventoryState.Slots[slotIndex] then
			table.insert(available, slotIndex)
			if #available >= count then
				break
			end
		end
	end

	return available
end

return SlotManagementService
