--!strict

local SlotManagementService = {}
SlotManagementService.__index = SlotManagementService

--- Creates a new SlotManagementService (no dependencies - pure domain logic)
function SlotManagementService.new()
	local self = setmetatable({}, SlotManagementService)
	return self
end

--- Finds the next available empty slot
function SlotManagementService:FindAvailableSlot(inventoryState: any): number?
	local totalSlots = inventoryState.Metadata.TotalSlots

	for slotIndex = 1, totalSlots do
		if not inventoryState.Slots[slotIndex] then
			return slotIndex
		end
	end

	return nil -- No available slots
end

--- Finds a slot by index and returns its data
function SlotManagementService:FindSlotByIndex(inventoryState: any, slotIndex: number): any?
	if slotIndex < 1 or slotIndex > inventoryState.Metadata.TotalSlots then
		return nil
	end

	return inventoryState.Slots[slotIndex]
end

--- Gets all occupied slot indices
function SlotManagementService:GetOccupiedSlots(inventoryState: any): { number }
	local occupied = {}

	for slotIndex in pairs(inventoryState.Slots) do
		table.insert(occupied, slotIndex)
	end

	table.sort(occupied)
	return occupied
end

--- Compacts inventory by removing gaps (moves items to lower indices)
-- Returns the compacted inventory state
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

--- Swaps two slots in the inventory
-- Returns the modified inventory state
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

--- Gets the next N available slots
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
