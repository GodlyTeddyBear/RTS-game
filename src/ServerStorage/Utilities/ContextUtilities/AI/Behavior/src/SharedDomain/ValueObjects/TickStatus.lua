--!strict

--[=[
    @class TickStatus
    Shared tick-result value object that validates the terminal status labels used by BehaviorSystem executors.
    @server
    @client
]=]

local ALLOWED_STATUSES = table.freeze({
	Success = true,
	Running = true,
	Fail = true,
})

local TickStatus = {}

--[=[
    Checks whether a value is one of the allowed tick-result status labels.
    @within TickStatus
    @param value any -- Value to inspect
    @return boolean -- Whether the value is a valid tick status
]=]
function TickStatus.IsValid(value: any): boolean
	return type(value) == "string" and ALLOWED_STATUSES[value] == true
end

--[=[
    Asserts that a value is one of the allowed tick-result status labels.
    @within TickStatus
    @param value any -- Value to validate
    @param label string? -- Optional label used in the error message
]=]
function TickStatus.Assert(value: any, label: string?)
	local normalizedLabel = if label ~= nil then label else "tickStatus"
	assert(TickStatus.IsValid(value), ("BehaviorSystem %s must be one of: Success, Running, Fail"):format(normalizedLabel))
end

return table.freeze(TickStatus)
