--!strict

--[=[
    @class ItemQuantity
    Immutable value object representing a validated item quantity within a stack.
    @server
]=]
local ItemQuantity = {}
ItemQuantity.__index = ItemQuantity

--[=[
    Create and validate an ItemQuantity, asserting the value is within [1, maxStack].
    @within ItemQuantity
    @param value number -- The quantity to validate
    @param maxStack number -- The maximum allowed stack size for the item
    @return ItemQuantity -- The validated quantity value object
    @error string -- Thrown if value is less than 1 or exceeds maxStack
]=]
function ItemQuantity.new(value: number, maxStack: number)
	assert(type(value) == "number", "Quantity must be a number")
	assert(value >= 1, "Quantity must be at least 1")
	assert(value <= maxStack, "Quantity exceeds maxStack limit of " .. tostring(maxStack))

	local self = setmetatable({}, ItemQuantity)
	self.Value = value
	self.MaxStack = maxStack

	return self
end

--[=[
    Return the numeric quantity value.
    @within ItemQuantity
    @return number -- The quantity
]=]
function ItemQuantity:GetValue(): number
	return self.Value
end

--[=[
    Return the maximum stack size this quantity was validated against.
    @within ItemQuantity
    @return number -- The max stack size
]=]
function ItemQuantity:GetMaxStack(): number
	return self.MaxStack
end

--[=[
    Check whether this quantity has reached the maximum stack size.
    @within ItemQuantity
    @return boolean -- True if value equals maxStack
]=]
function ItemQuantity:IsAtCapacity(): boolean
	return self.Value >= self.MaxStack
end

return ItemQuantity
