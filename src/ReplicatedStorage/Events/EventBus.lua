--!strict

--[[
	EventBus - Node.js EventEmitter-style event bus built on GoodSignal.

	Provides string-keyed pub/sub for decoupled cross-context communication.
	Signals are created lazily on first subscription or emission.
	Accepts optional middleware objects that run on every Emit before firing.

	Usage:
		local validator = EventValidator.new(schemas)
		local logger = EventMiddleware.new()

		local bus = EventBus.new({ validator, logger })

		bus:On("WorkerHired", function(userId, workerId)
			print("Worker hired!", workerId)
		end)

		bus:Emit("WorkerHired", userId, workerId)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GoodSignal = require(ReplicatedStorage.Packages.Goodsignal)
local Result = require(ReplicatedStorage.Utilities.Result)

type Signal = GoodSignal.Signal<...any>
type Connection = GoodSignal.Connection

type Middleware = { Run: (self: any, eventName: string, ...any) -> () }

--[=[
	@class EventBus
	Node.js EventEmitter-style pub/sub event bus for cross-context communication.
	@server
]=]
local EventBus = {}
EventBus.__index = EventBus

export type EventBus = typeof(setmetatable({} :: {
	_signals: { [string]: Signal },
	_middleware: { Middleware },
}, EventBus))

-- Traverse GoodSignal's internal linked list to count active handlers.
local function countConnectedHandlers(signal: Signal): number
	local count = 0
	local item = (signal :: any)._handlerListHead
	while item do
		if item._connected then
			count += 1
		end
		item = item._next
	end
	return count
end

-- Route event telemetry into the Result event logging pipeline.
local function mentionEvent(label: string, message: string, data: { [string]: any }?)
	Result.MentionEvent(label, message, data)
end

--[=[
	Construct a new EventBus with optional middleware chain.
	@within EventBus
	@param middleware {Middleware}? -- Optional array of middleware objects; each must have a Run method
	@return EventBus -- A new event bus instance
]=]
function EventBus.new(middleware: { Middleware }?): EventBus
	return setmetatable({
		_signals = {},
		_middleware = middleware or {},
	}, EventBus) :: any
end

-- Lazy-create a signal on first subscription or emit; reuse if it exists.
function EventBus._GetOrCreateSignal(self: EventBus, eventName: string): Signal
	local signal = self._signals[eventName]
	if not signal then
		signal = GoodSignal.new()
		self._signals[eventName] = signal
	end
	return signal
end

--[=[
	Register a persistent listener for an event.
	@within EventBus
	@param eventName string -- The event identifier
	@param callback (...any) -> () -- Handler that fires on every emission
	@return Connection -- A connection that can be disconnected
]=]
function EventBus.On(self: EventBus, eventName: string, callback: (...any) -> ()): Connection
	mentionEvent("Events:Bus", "Registered persistent listener for event", {
		operation = "On",
		eventName = eventName,
	})
	return self:_GetOrCreateSignal(eventName):Connect(callback)
end

--[=[
	Register a one-time listener that fires only on the next emission.
	@within EventBus
	@param eventName string -- The event identifier
	@param callback (...any) -> () -- Handler that fires on the next emission only
	@return Connection -- A connection that can be disconnected
]=]
function EventBus.Once(self: EventBus, eventName: string, callback: (...any) -> ()): Connection
	mentionEvent("Events:Bus", "Registered one-time listener for event", {
		operation = "Once",
		eventName = eventName,
	})
	return self:_GetOrCreateSignal(eventName):Once(callback)
end

--[=[
	Emit an event to all registered listeners.
	@within EventBus
	@param eventName string -- The event identifier
	@param ... any -- Variable arguments to pass to listeners
]=]
function EventBus.Emit(self: EventBus, eventName: string, ...: any)
	-- Run all middleware before firing (validation, logging, etc.)
	for _, middleware in self._middleware do
		middleware:Run(eventName, ...)
	end

	-- Fire the event if there are listeners registered
	local signal = self._signals[eventName]
	if signal then
		local listenerCount = countConnectedHandlers(signal)
		mentionEvent("Events:Emit", "Dispatched event to connected listeners", {
			eventName = eventName,
			argCount = select("#", ...),
			listenerCount = listenerCount,
		})
		signal:Fire(...)
	else
		mentionEvent("Events:Emit", "Emit completed with no connected listeners", {
			eventName = eventName,
			argCount = select("#", ...),
		})
	end
end

--[=[
	Yield until an event is emitted, then return its arguments.
	@within EventBus
	@param eventName string -- The event identifier
	@return ...any -- Arguments from the first emission
	@yields
]=]
function EventBus.Wait(self: EventBus, eventName: string): ...any
	mentionEvent("Events:Bus", "Waiting for next event emission", {
		operation = "Wait",
		eventName = eventName,
	})
	return self:_GetOrCreateSignal(eventName):Wait()
end

--[=[
	Disconnect all listeners for an event, or for all events.
	@within EventBus
	@param eventName string? -- The event identifier; if nil, removes all listeners globally
]=]
function EventBus.RemoveAllListeners(self: EventBus, eventName: string?)
	if eventName then
		-- Disconnect all listeners for a specific event only
		mentionEvent("Events:Bus", "Removing all listeners for specific event", {
			operation = "RemoveAllListeners",
			eventName = eventName,
		})

		local signal = self._signals[eventName]
		if signal then
			signal:DisconnectAll()
		end
	else
		-- Disconnect all listeners across all events
		mentionEvent("Events:Bus", "Removing all listeners for every event", {
			operation = "RemoveAllListeners",
		})

		for _, signal in self._signals do
			signal:DisconnectAll()
		end
	end
end

--[=[
	Count the number of active listeners for an event.
	@within EventBus
	@param eventName string -- The event identifier
	@return number -- Number of connected listeners (0 if event has no listeners)
]=]
function EventBus.ListenerCount(self: EventBus, eventName: string): number
	local signal = self._signals[eventName]
	if not signal then
		mentionEvent("Events:Bus", "Computed listener count for event", {
			operation = "ListenerCount",
			eventName = eventName,
			listenerCount = 0,
		})
		return 0
	end

	local count = countConnectedHandlers(signal)
	mentionEvent("Events:Bus", "Computed listener count for event", {
		operation = "ListenerCount",
		eventName = eventName,
		listenerCount = count,
	})
	return count
end

--[=[
	Return an array of all event names that have active listeners.
	@within EventBus
	@return {string} -- Array of event identifiers with connected listeners
]=]
function EventBus.EventNames(self: EventBus): { string }
	local names = {}
	for name, signal in self._signals do
		if countConnectedHandlers(signal) > 0 then
			table.insert(names, name)
		end
	end

	mentionEvent("Events:Bus", "Collected event names with active listeners", {
		operation = "EventNames",
		eventCount = #names,
	})
	return names
end

return EventBus
