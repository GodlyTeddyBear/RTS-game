--!strict

--[=[
	@class FlagValidator
	Domain service to validate dialogue flag names and values against naming and type constraints.
	@server
]=]

local Errors = require(script.Parent.Parent.Parent.Errors)
local FlagName = require(script.Parent.Parent.ValueObjects.FlagName)
local Result = require(game:GetService("ReplicatedStorage").Utilities.Result)

local Ok = Result.Ok
local Err = Result.Err

local VALID_VALUE_TYPES = table.freeze({
	boolean = true,
	string = true,
	number = true,
})

local FlagValidator = {}
FlagValidator.__index = FlagValidator

export type TFlagValidator = typeof(setmetatable({}, FlagValidator))

function FlagValidator.new(): TFlagValidator
	return setmetatable({}, FlagValidator)
end

--[=[
	Validate a flag name against naming constraints (alphanumeric + underscores, max 64 chars).
	@within FlagValidator
	@param flagName string -- The flag name to validate
	@return Result<nil> -- Success if valid, error otherwise
]=]
function FlagValidator:ValidateFlagName(flagName: string): Result.Result<nil>
	local success, _ = pcall(function()
		FlagName.new(flagName)
	end)

	if not success then
		return Err("InvalidFlagName", Errors.INVALID_FLAG_NAME)
	end

	return Ok(nil)
end

--[=[
	Validate a flag value is one of the allowed types: boolean, string, or number.
	@within FlagValidator
	@param flagValue any -- The value to validate
	@return Result<nil> -- Success if valid, error otherwise
]=]
function FlagValidator:ValidateFlagValue(flagValue: any): Result.Result<nil>
	if not VALID_VALUE_TYPES[type(flagValue)] then
		return Err("InvalidFlagValue", Errors.INVALID_FLAG_VALUE)
	end

	return Ok(nil)
end

return FlagValidator
