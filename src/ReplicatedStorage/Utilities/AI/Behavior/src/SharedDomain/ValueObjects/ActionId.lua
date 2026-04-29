--!strict

--[=[
    @class ActionId
    Shared value object that normalizes non-empty action identifiers used by BehaviorSystem runtime dispatch.
    @prop Value string -- Normalized action identifier string
    @readonly
    @server
    @client
]=]

local ActionId = {}
ActionId.__index = ActionId

--[=[
    Creates a frozen action-id wrapper from a non-empty string.
    @within ActionId
    @param value any -- Raw action id value
    @return ActionId -- Frozen wrapper around the validated action id string
]=]
function ActionId.new(value: any)
	assert(type(value) == "string" and #value > 0, "BehaviorSystem ActionId must be a non-empty string")

	local self = setmetatable({}, ActionId)
	self.Value = value
	return table.freeze(self)
end

--[=[
    Normalizes an action-id label into a non-empty string.
    @within ActionId
    @param value any -- Raw action id value
    @param label string? -- Optional label used in the error message
    @return string -- Validated action id string
]=]
function ActionId.From(value: any, label: string?)
	local normalizedLabel = if label ~= nil then label else "actionId"
	assert(type(value) == "string" and #value > 0, ("BehaviorSystem %s must be a non-empty string"):format(normalizedLabel))
	return value
end

return table.freeze(ActionId)
