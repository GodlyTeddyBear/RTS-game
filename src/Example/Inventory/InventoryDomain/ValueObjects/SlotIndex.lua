--!strict

local SlotIndex = {}
SlotIndex.__index = SlotIndex

--- Creates and validates a SlotIndex value object
-- Ensures slot index is within valid bounds (1 to totalCapacity)
function SlotIndex.new(value: number, totalCapacity: number)
	assert(type(value) == "number", "SlotIndex must be a number")
	assert(value >= 1, "SlotIndex must be at least 1")
	assert(value <= totalCapacity, "SlotIndex exceeds total capacity of " .. tostring(totalCapacity))

	local self = setmetatable({}, SlotIndex)
	self.Value = value
	self.TotalCapacity = totalCapacity

	return self
end

--- Gets the slot index value
function SlotIndex:GetValue(): number
	return self.Value
end

--- Gets the total capacity
function SlotIndex:GetTotalCapacity(): number
	return self.TotalCapacity
end

--- Checks if this is the last slot
function SlotIndex:IsLastSlot(): boolean
	return self.Value :: number >= self.TotalCapacity :: number
end

return SlotIndex
