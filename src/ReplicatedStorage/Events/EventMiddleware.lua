--!strict

--[[
	EventMiddleware - EventBus middleware that bridges emits into Result event logging.

	Middleware runs on every Emit call before the signal fires.
	Used to route event telemetry into the unified LogContext pipeline.

	Usage:
		local middleware = EventMiddleware.new()
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Result = require(ReplicatedStorage.Utilities.Result)

--[=[
	@class EventMiddleware
	EventBus middleware that captures event payloads and routes telemetry.
	@server
]=]
local EventMiddleware = {}
EventMiddleware.__index = EventMiddleware

export type EventMiddleware = typeof(setmetatable({} :: {
	_label: string,
}, EventMiddleware))

--[=[
	Construct a new EventMiddleware instance with an optional label.
	@within EventMiddleware
	@param label string? -- Label for logging; defaults to "Events:Emit"
	@return EventMiddleware -- A new middleware instance
]=]
function EventMiddleware.new(label: string?): EventMiddleware
	return setmetatable({
		_label = label or "Events:Emit",
	}, EventMiddleware) :: any
end

--[=[
	Capture an event's payload signature and log it.
	@within EventMiddleware
	@param eventName string -- The event identifier
	@param ... any -- Arguments passed to Emit; captured for telemetry
]=]
function EventMiddleware.Run(self: EventMiddleware, eventName: string, ...: any)
	-- Collect argument types for telemetry logging
	local argCount = select("#", ...)
	local args = { ... }
	local argTypes = table.create(argCount)
	for i = 1, argCount do
		argTypes[i] = typeof(args[i])
	end

	Result.MentionEvent(self._label, "Emit middleware captured event payload signature", {
		eventName = eventName,
		argCount = argCount,
		argTypes = argTypes,
	})
end

return EventMiddleware
