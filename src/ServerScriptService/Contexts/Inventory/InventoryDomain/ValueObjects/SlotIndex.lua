--!strict

--[=[
    @class SlotIndex
    Immutable value object representing a validated inventory slot position.
    @server
]=]
local SlotIndex = {}
SlotIndex.__index = SlotIndex

--[=[
    Create and validate a SlotIndex, asserting the value is within [1, totalCapacity].
    @within SlotIndex
    @param value number -- The slot position to validate
    @param totalCapacity number -- The upper bound of the inventory
    @return SlotIndex -- The validated slot index value object
    @error string -- Thrown if value is out of range
]=]
function SlotIndex.new(value: number, totalCapacity: number)
	assert(type(value) == "number", "SlotIndex must be a number")
	assert(value >= 1, "SlotIndex must be at least 1")
	assert(value <= totalCapacity, "SlotIndex exceeds total capacity of " .. tostring(totalCapacity))

	local self = setmetatable({}, SlotIndex)
	self.Value = value
	self.TotalCapacity = totalCapacity

	return self
end

--[=[
    Return the numeric slot position.
    @within SlotIndex
    @return number -- The slot index value
]=]
function SlotIndex:GetValue(): number
	return self.Value
end

--[=[
    Return the inventory's total slot capacity used for bounds validation.
    @within SlotIndex
    @return number -- The total capacity
]=]
function SlotIndex:GetTotalCapacity(): number
	return self.TotalCapacity
end

--[=[
    Check whether this slot is at the last position in the inventory.
    @within SlotIndex
    @return boolean -- True if value equals totalCapacity
]=]
function SlotIndex:IsLastSlot(): boolean
	return self.Value :: number >= self.TotalCapacity :: number
end

return SlotIndex
