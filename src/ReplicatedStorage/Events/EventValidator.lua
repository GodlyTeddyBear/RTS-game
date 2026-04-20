--!strict

--[[
	EventValidator - Middleware that validates event payloads against a schema.

	Schemas are a table mapping event name -> array of expected type strings:
		{ ["Combat.WaveCompleted"] = { "number", "number" } }

	Checks:
		1. Event name exists in the schema
		2. Argument count matches
		3. Each argument's type matches the schema

	Usage:
		local validator = EventValidator.new(schemas)
		-- Pass to EventBus as middleware
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Result = require(ReplicatedStorage.Utilities.Result)

--[=[
	@class EventValidator
	EventBus middleware that validates event payloads against type schemas.
	@server
]=]
local EventValidator = {}
EventValidator.__index = EventValidator

--[=[
	@type Schema { [string]: { string } }
	@within EventValidator
	Maps event name to array of expected argument type strings.
]=]
export type Schema = { [string]: { string } }

export type EventValidator = typeof(setmetatable({} :: {
	_schemas: Schema,
}, EventValidator))

--[=[
	Construct a new EventValidator instance.
	@within EventValidator
	@param schemas Schema -- Event name to expected argument types mapping
	@return EventValidator -- A new validator instance
]=]
function EventValidator.new(schemas: Schema): EventValidator
	return setmetatable({
		_schemas = schemas,
	}, EventValidator) :: any
end

--[=[
	Validate an event's payload against its registered schema.
	@within EventValidator
	@param eventName string -- The event identifier
	@param ... any -- Arguments passed to Emit; checked against schema
]=]
function EventValidator.Run(self: EventValidator, eventName: string, ...: any)
	local function report(message: string, data: { [string]: any }?)
		Result.MentionEvent("Events:Validator", message, data)
	end

	-- Check 1: Event name must be in the schema
	local schema = self._schemas[eventName]
	if not schema then
		report("Validation skipped: event is missing from schema", {
			eventName = eventName,
		})
		return
	end

	-- Check 2: Argument count must match expected count
	local args = { ... }
	local argCount = select("#", ...)
	local expectedCount = #schema

	if argCount ~= expectedCount then
		report("Validation failed: argument count mismatch", {
			eventName = eventName,
			expectedCount = expectedCount,
			actualCount = argCount,
		})
		return
	end

	-- Check 3: Each argument type must match expected type in schema
	local typeMismatchCount = 0
	for i, expectedType in schema do
		local actualType = typeof(args[i])
		if actualType ~= expectedType then
			typeMismatchCount += 1
			report("Validation failed: argument type mismatch", {
				eventName = eventName,
				argIndex = i,
				expectedType = expectedType,
				actualType = actualType,
			})
		end
	end

	-- Log success if all checks passed
	if typeMismatchCount == 0 then
		report("Validation passed for emitted event payload", {
			eventName = eventName,
			argCount = argCount,
		})
	end
end

return EventValidator
