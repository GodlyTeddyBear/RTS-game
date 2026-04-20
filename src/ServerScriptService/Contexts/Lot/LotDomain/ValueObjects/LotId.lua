--!strict

--[[
	Lot ID - Self-validating value object for lot identifiers

	Responsibility: Encapsulate lot ID generation and validation.
	Ensures lot IDs follow format: "Lot_UserId_Counter"
	Immutable after construction.
]]

--[=[
	@class LotId
	Self-validating value object for lot identifiers.
	Ensures format "Lot_UserId_Counter" and is immutable.
	@server
]=]

local LotId = {}
LotId.__index = LotId

export type LotId = typeof(setmetatable(
	{} :: {
		_userId: number,
		_counter: number,
		_id: string,
	},
	LotId
))

--[=[
	Create a new LotId value object.
	@within LotId
	@param userId number -- The player's user ID (must be positive)
	@param counter number -- The lot counter for this player (must be positive)
	@return LotId -- Frozen value object
	@error string -- If userId or counter are not positive numbers
]=]
function LotId.new(userId: number, counter: number): LotId
	assert(type(userId) == "number", "UserId must be a number")
	assert(userId > 0, "UserId must be positive")
	assert(type(counter) == "number", "Counter must be a number")
	assert(counter > 0, "Counter must be positive")

	local self = setmetatable({}, LotId)
	self._userId = userId
	self._counter = counter
	self._id = `Lot_{userId}_{counter}`
	return table.freeze(self)
end

--[=[
	Get the string representation of this lot ID.
	@within LotId
	@return string -- The lot ID in format "Lot_UserId_Counter"
]=]
function LotId:GetId(): string
	return self._id
end

--[=[
	Get the user ID component of this lot ID.
	@within LotId
	@return number -- The player's user ID
]=]
function LotId:GetUserId(): number
	return self._userId
end

--[=[
	Get the counter component of this lot ID.
	@within LotId
	@return number -- The lot counter for this player
]=]
function LotId:GetCounter(): number
	return self._counter
end

return LotId
