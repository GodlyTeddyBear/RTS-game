--!strict

--[[
	LotAreaId - Self-validating value object for lot area names

	Wraps the name of a LotArea Part (e.g., "LotArea1").
	Immutable after construction.
]]

--[=[
	@class LotAreaId
	Self-validating value object for lot area identifiers.
	Enforces string type and length constraints (1-64 characters).
	Immutable after construction.
	@server
]=]
local LotAreaId = {}
LotAreaId.__index = LotAreaId

export type LotAreaId = typeof(setmetatable(
	{} :: {
		_name: string,
	},
	LotAreaId
))

--[=[
	Create a new LotAreaId value object.
	Validates that the name is a non-empty string with at most 64 characters.
	@within LotAreaId
	@param name string -- The lot area name to wrap
	@return LotAreaId -- A new immutable value object
	@error string -- Thrown if name is not a string, empty, or exceeds 64 characters
]=]
function LotAreaId.new(name: string): LotAreaId
	assert(type(name) == "string", "LotAreaId must be a string")
	assert(#name > 0, "LotAreaId must not be empty")
	assert(#name <= 64, "LotAreaId must be at most 64 characters")

	local self = setmetatable({}, LotAreaId)
	self._name = name
	return table.freeze(self)
end

--[=[
	Get the wrapped lot area name.
	@within LotAreaId
	@return string -- The stored lot area name
]=]
function LotAreaId:GetName(): string
	return self._name
end

return LotAreaId
