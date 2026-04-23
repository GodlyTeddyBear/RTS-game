--!strict

--[=[
    @class ActionStatus
    Shared action-state value object that validates the lifecycle labels used by BehaviorSystem runtime dispatch.
    @server
    @client
]=]

local ALLOWED_STATUSES = table.freeze({
	Idle = true,
	Committed = true,
	Running = true,
})

local ActionStatus = {}

--[=[
    Checks whether a value is one of the allowed action-state labels.
    @within ActionStatus
    @param value any -- Value to inspect
    @return boolean -- Whether the value is a valid action status
]=]
function ActionStatus.IsValid(value: any): boolean
	return type(value) == "string" and ALLOWED_STATUSES[value] == true
end

--[=[
    Asserts that a value is one of the allowed action-state labels.
    @within ActionStatus
    @param value any -- Value to validate
    @param label string? -- Optional label used in the error message
]=]
function ActionStatus.Assert(value: any, label: string?)
	local normalizedLabel = if label ~= nil then label else "actionState"
	assert(ActionStatus.IsValid(value), ("BehaviorSystem %s must be one of: Idle, Committed, Running"):format(normalizedLabel))
end

return table.freeze(ActionStatus)
