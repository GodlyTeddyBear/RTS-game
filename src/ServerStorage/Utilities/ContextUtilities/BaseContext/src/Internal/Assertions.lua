--!strict

--[=[
    @class Assertions
    Internal assertion helpers used by BaseContext validation and runtime guards.
    @server
]=]

local Assertions = {}

--[=[
    Asserts that `value` is a non-empty string.
    @within Assertions
    @param value any -- Value to validate.
    @param label string -- Label used in the error message.
    @error string -- Raised when `value` is not a non-empty string.
]=]
function Assertions.AssertNonEmptyString(value: any, label: string)
	assert(type(value) == "string" and value ~= "", ("%s must be a non-empty string"):format(label))
end

--[=[
    Asserts that `value` is either `nil` or a non-empty string.
    @within Assertions
    @param value string? -- Optional string value to validate.
    @param label string -- Label used in the error message.
    @error string -- Raised when `value` is present but empty.
]=]
function Assertions.AssertOptionalNonEmptyString(value: string?, label: string)
	if value == nil then
		return
	end

	Assertions.AssertNonEmptyString(value, label)
end

--[=[
    Asserts that `value` is a function.
    @within Assertions
    @param value any -- Value to validate.
    @param label string -- Label used in the error message.
    @error string -- Raised when `value` is not a function.
]=]
function Assertions.AssertFunction(value: any, label: string)
	assert(type(value) == "function", ("%s must be a function"):format(label))
end

--[=[
    Asserts that `value` is a function or method-name string.
    @within Assertions
    @param value any -- Callback reference to validate.
    @param label string -- Label used in the error message.
    @error string -- Raised when `value` is neither a function nor a string.
]=]
function Assertions.AssertCallbackOrMethodName(value: any, label: string)
	local valueType = type(value)
	assert(valueType == "function" or valueType == "string", ("%s must be a function or method name string"):format(label))
	if valueType == "string" then
		Assertions.AssertNonEmptyString(value, label)
	end
end

return table.freeze(Assertions)
