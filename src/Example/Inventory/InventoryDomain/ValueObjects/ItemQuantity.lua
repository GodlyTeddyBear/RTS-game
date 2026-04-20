--!strict

local ItemQuantity = {}
ItemQuantity.__index = ItemQuantity

--- Creates and validates an ItemQuantity value object
-- Ensures quantity is within valid bounds (1 to maxStack)
function ItemQuantity.new(value: number, maxStack: number)
	assert(type(value) == "number", "Quantity must be a number")
	assert(value >= 1, "Quantity must be at least 1")
	assert(value <= maxStack, "Quantity exceeds maxStack limit of " .. tostring(maxStack))

	local self = setmetatable({}, ItemQuantity)
	self.Value = value
	self.MaxStack = maxStack

	return self
end

--- Gets the quantity value
function ItemQuantity:GetValue(): number
	return self.Value
end

--- Gets the max stack
function ItemQuantity:GetMaxStack(): number
	return self.MaxStack
end

--- Checks if this quantity is at max capacity
function ItemQuantity:IsAtCapacity(): boolean
	return self.Value >= self.MaxStack
end

return ItemQuantity
