--!strict

--[[
	FlagName - Self-validating value object for player flag names

	Rules:
	- Must be a string
	- Must be non-empty
	- Must be <= 50 characters
	- Must match pattern: starts with letter, alphanumeric + underscores only
]]

local ERROR_MESSAGES = table.freeze({
	NOT_STRING = "Flag name must be a string",
	EMPTY = "Flag name must not be empty",
	TOO_LONG = "Flag name must be 50 characters or less",
	INVALID_FORMAT = "Flag name must start with a letter and contain only letters, numbers, and underscores",
})

local FlagName = {}
FlagName.__index = FlagName

--[=[
	Creates a new FlagName value object.

	@param value string - The flag name to validate
	@return FlagName - Frozen, immutable flag name value object
	@throws Error if name is invalid

	Example:
		local name = FlagName.new("HasMetEldric")
		local name2 = FlagName.new("QuestProgress")
]=]
function FlagName.new(value: string)
	assert(type(value) == "string", ERROR_MESSAGES.NOT_STRING)
	assert(#value > 0, ERROR_MESSAGES.EMPTY)
	assert(#value <= 50, ERROR_MESSAGES.TOO_LONG)
	assert(string.match(value, "^[A-Za-z][A-Za-z0-9_]*$") ~= nil, ERROR_MESSAGES.INVALID_FORMAT)

	local self = setmetatable({}, FlagName)
	self.Value = value

	return table.freeze(self)
end

--[=[
	Gets the flag name string.

	@return string - The flag name
]=]
function FlagName:GetValue(): string
	return self.Value
end

return FlagName
