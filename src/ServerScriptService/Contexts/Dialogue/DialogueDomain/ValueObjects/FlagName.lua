--!strict

--[=[
	@class FlagName
	Value object representing a valid dialogue flag name. Enforces constraints on construction.
	@server
]=]

local FlagName = {}
FlagName.__index = FlagName

export type TFlagName = typeof(setmetatable({} :: { Name: string }, FlagName))

--[=[
	@prop Name string
	@within FlagName
	@readonly
	The flag name string.
]=]

--[=[
	Create a flag name value object. Validates the name is non-empty, max 64 chars, and contains only alphanumerics and underscores.
	@within FlagName
	@param value string -- The flag name to create
	@return TFlagName -- The frozen flag name value object
	@error string -- If any constraint is violated
]=]
function FlagName.new(value: string): TFlagName
	assert(type(value) == "string", "Flag name must be a string")
	assert(#value > 0, "Flag name must not be empty")
	assert(#value <= 64, "Flag name must be 64 characters or less")
	assert(string.match(value, "^[%w_]+$") ~= nil, "Flag name can only contain letters, numbers, and underscores")

	local self = setmetatable({
		Name = value,
	}, FlagName)

	return table.freeze(self)
end

--[=[
	Get the flag name string.
	@within FlagName
	@return string -- The flag name
]=]
function FlagName:GetName(): string
	return self.Name
end

return FlagName
