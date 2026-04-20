--!strict

--[[
	FlagValidator - Validates flag names and values

	Wraps FlagName value object construction in pcall() to convert
	assertion failures into user-friendly validation errors.
]]

local FlagName = require(script.Parent.Parent.ValueObjects.FlagName)
local Errors = require(script.Parent.Parent.Parent.Errors)

local VALID_VALUE_TYPES = {
	["boolean"] = true,
	["string"] = true,
	["number"] = true,
}

local FlagValidator = {}
FlagValidator.__index = FlagValidator

function FlagValidator.new()
	local self = setmetatable({}, FlagValidator)
	return self
end

--[=[
	Validates a flag name using the FlagName value object.

	@param flagName string - The flag name to validate
	@return boolean - True if valid
	@return { string } - Array of error messages (empty if valid)
]=]
function FlagValidator:ValidateFlagName(flagName: string): (boolean, { string })
	local errors = {}

	local nameSuccess, nameError = pcall(function()
		FlagName.new(flagName)
	end)
	if not nameSuccess then
		table.insert(errors, Errors.INVALID_FLAG_NAME .. ": " .. tostring(nameError))
	end

	return #errors == 0, errors
end

--[=[
	Validates a flag value (must be boolean, string, or number).

	@param flagValue any - The value to validate
	@return boolean - True if valid
	@return { string } - Array of error messages (empty if valid)
]=]
function FlagValidator:ValidateFlagValue(flagValue: any): (boolean, { string })
	local errors = {}

	if not VALID_VALUE_TYPES[type(flagValue)] then
		table.insert(errors, Errors.INVALID_FLAG_VALUE)
	end

	return #errors == 0, errors
end

--[=[
	Validates both flag name and value.

	@param flagName string - The flag name
	@param flagValue any - The flag value
	@return boolean - True if both valid
	@return { string } - Array of all error messages
]=]
function FlagValidator:ValidateFlag(flagName: string, flagValue: any): (boolean, { string })
	local errors = {}

	local nameValid, nameErrors = self:ValidateFlagName(flagName)
	if not nameValid then
		for _, err in ipairs(nameErrors) do
			table.insert(errors, err)
		end
	end

	local valueValid, valueErrors = self:ValidateFlagValue(flagValue)
	if not valueValid then
		for _, err in ipairs(valueErrors) do
			table.insert(errors, err)
		end
	end

	return #errors == 0, errors
end

return FlagValidator
