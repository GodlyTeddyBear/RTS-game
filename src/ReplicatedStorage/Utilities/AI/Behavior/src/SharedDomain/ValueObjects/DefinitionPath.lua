--!strict

--[=[
    @class DefinitionPath
    Shared value object that normalizes symbolic-definition path labels for validation errors.
    @prop Value string -- Normalized definition path string
    @readonly
    @server
    @client
]=]

local DefinitionPath = {}
DefinitionPath.__index = DefinitionPath

--[=[
    Creates a frozen definition-path wrapper from a non-empty string.
    @within DefinitionPath
    @param value any -- Raw path value
    @return DefinitionPath -- Frozen wrapper around the validated path string
]=]
function DefinitionPath.new(value: any)
	assert(type(value) == "string" and #value > 0, "BehaviorSystem definition path must be a non-empty string")

	local self = setmetatable({}, DefinitionPath)
	self.Value = value
	return table.freeze(self)
end

--[=[
    Normalizes a definition-path label into a non-empty string.
    @within DefinitionPath
    @param value any -- Raw path value
    @return string -- Validated path string
]=]
function DefinitionPath.From(value: any): string
	assert(type(value) == "string" and #value > 0, "BehaviorSystem definition path must be a non-empty string")
	return value
end

return table.freeze(DefinitionPath)
