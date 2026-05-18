--!strict

local Validation = {}

local function _AssertOptionalNonNegativeNumber(value: any, name: string)
	if value == nil then
		return
	end

	assert(type(value) == "number", string.format("%s must be a number", name))
	assert(value >= 0, string.format("%s must be >= 0", name))
end

local function _AssertFunction(value: any, name: string)
	assert(type(value) == "function", string.format("%s must be a function", name))
end

function Validation.AssertTime(currentTime: number)
	assert(type(currentTime) == "number", "currentTime must be a number")
end

function Validation.AssertClock(clock: any)
	if clock == nil then
		return
	end

	_AssertFunction(clock, "Clock")
end

function Validation.AssertGroupName(groupName: string)
	assert(type(groupName) == "string", "groupName must be a string")
	assert(groupName ~= "", "groupName must not be empty")
end

function Validation.ValidateValueConfig(config: any)
	assert(type(config) == "table", "CachePlus.Value config must be a table")
	_AssertFunction(config.Resolver, "Resolver")
	_AssertOptionalNonNegativeNumber(config.TtlSeconds, "TtlSeconds")
	Validation.AssertClock(config.Clock)
end

function Validation.ValidateMapConfig(config: any)
	assert(type(config) == "table", "CachePlus.Map config must be a table")
	_AssertFunction(config.Resolver, "Resolver")
	_AssertOptionalNonNegativeNumber(config.TtlSeconds, "TtlSeconds")
	Validation.AssertClock(config.Clock)
end

function Validation.ValidateGroupedMapConfig(config: any)
	assert(type(config) == "table", "CachePlus.GroupedMap config must be a table")
	assert(type(config.Groups) == "table", "Groups must be a table")
	_AssertFunction(config.BuildValue, "BuildValue")
	_AssertOptionalNonNegativeNumber(config.EntryTtlSeconds, "EntryTtlSeconds")
	Validation.AssertClock(config.Clock)

	for groupName, groupConfig in pairs(config.Groups) do
		Validation.AssertGroupName(groupName)
		assert(type(groupConfig) == "table", string.format("Group %s must be a table", groupName))
		_AssertFunction(groupConfig.Resolver, string.format("Groups.%s.Resolver", groupName))
		_AssertOptionalNonNegativeNumber(groupConfig.TtlSeconds, string.format("Groups.%s.TtlSeconds", groupName))
	end
end

return table.freeze(Validation)
