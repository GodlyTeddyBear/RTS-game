--!strict

--[=[
    @class ResultAccess
    Internal helpers that unwrap `Result` values returned by registry modules.
    @server
]=]

local ResultAccess = {}

-- Extracts the value from a successful `Result` and raises on failure.
--[=[
    Returns the success value from a `Result`.
    @within ResultAccess
    @param result any -- Result table to inspect.
    @param label string -- Label used in validation and error messages.
    @return any -- Unwrapped success value.
    @error string -- Raised when the result is missing or failed.
]=]
function ResultAccess.RequireValue(result: any, label: string): any
	assert(type(result) == "table" and result.success ~= nil, ("%s must return a Result table"):format(label))

	if result.success then
		return result.value
	end

	local message = result.message or result.type or "Unknown error"
	error(("%s failed: %s"):format(label, tostring(message)), 2)
end

return table.freeze(ResultAccess)
