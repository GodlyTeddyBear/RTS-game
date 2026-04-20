-- -----------------------------------------------------------------------------
--               Batched Yield-Safe Signal Implementation                     --
-- This is a Signal class which has effectively identical behavior to a       --
-- normal RBXScriptSignal, with the only difference being a couple extra      --
-- stack frames at the bottom of the stack trace when an error is thrown.     --
-- This implementation caches runner coroutines, so the ability to yield in   --
-- the signal handlers comes at minimal extra cost over a naive signal        --
-- implementation that either always or never spawns a thread.                --
--                                                                            --
-- License:                                                                   --
--   Licensed under the MIT license.                                          --
--                                                                            --
-- Authors:                                                                   --
--   stravant - July 31st, 2021 - Created the file.                           --
--   sleitnick - August 3rd, 2021 - Modified for Knit.                        --
-- -----------------------------------------------------------------------------

--[=[
	@class Connection
	Represents a single connection from a handler to a Signal.
	Call Disconnect() to stop receiving events on this connection.
]=]
export type Connection = {
	Disconnect: (self: Connection) -> (),
	Destroy: (self: Connection) -> (),
	Connected: boolean,
}

--[=[
	@class Signal
	A yield-safe custom signal implementation compatible with RBXScriptSignal.
	Supports connecting handlers, firing events with variadic arguments, and yielding with Wait().
	@generic T...
]=]
export type Signal<T...> = {
	Fire: (self: Signal<T...>, T...) -> (),
	FireDeferred: (self: Signal<T...>, T...) -> (),
	Connect: (self: Signal<T...>, fn: (T...) -> ()) -> Connection,
	Once: (self: Signal<T...>, fn: (T...) -> ()) -> Connection,
	DisconnectAll: (self: Signal<T...>) -> (),
	GetConnections: (self: Signal<T...>) -> { Connection },
	Destroy: (self: Signal<T...>) -> (),
	Wait: (self: Signal<T...>) -> T...,
}

-- Reusable coroutine thread for running event handlers without allocating a new thread per fire.
-- This reduces garbage collection pressure for frequently-fired signals.
local freeRunnerThread = nil

-- Acquires the idle runner thread, executes the handler function, then releases the thread back to the pool.
-- If another handler already grabbed it, the old thread is discarded and will be garbage collected.
local function acquireRunnerThreadAndCallEventHandler(fn, ...)
	local acquiredRunnerThread = freeRunnerThread
	freeRunnerThread = nil
	fn(...)
	-- Release the thread back to the pool for reuse
	freeRunnerThread = acquiredRunnerThread
end

-- Coroutine body that yields repeatedly to be resumed with handler functions.
-- Enables handlers to yield safely without blocking the Fire() call itself.
local function runEventHandlerInFreeThread(...)
	acquireRunnerThreadAndCallEventHandler(...)
	while true do
		-- Yield to wait for the next handler to run
		acquireRunnerThreadAndCallEventHandler(coroutine.yield())
	end
end

-- Connection class
local Connection = {}
Connection.__index = Connection

function Connection:Disconnect()
	-- Guard against double disconnect
	if not self.Connected then
		return
	end
	self.Connected = false

	-- Unlink this connection from the signal's handler list
	if self._signal._handlerListHead == self then
		-- This is the head; move head pointer to next handler
		self._signal._handlerListHead = self._next
	else
		-- Walk the linked list to find the previous handler, then relink
		local prev = self._signal._handlerListHead
		while prev and prev._next ~= self do
			prev = prev._next
		end
		if prev then
			prev._next = self._next
		end
	end
end

Connection.Destroy = Connection.Disconnect

-- Make Connection strict
setmetatable(Connection, {
	__index = function(_tb, key)
		error(("Attempt to get Connection::%s (not a valid member)"):format(tostring(key)), 2)
	end,
	__newindex = function(_tb, key, _value)
		error(("Attempt to set Connection::%s (not a valid member)"):format(tostring(key)), 2)
	end,
})

local Signal = {}
Signal.__index = Signal

--[=[
	@method new
	@within Signal
	Creates a new Signal instance with an empty handler list.
	@generic T...
	@return Signal<T...> -- A new Signal ready to connect handlers
]=]
function Signal.new<T...>(): Signal<T...>
	local self = setmetatable({
		_handlerListHead = false,  -- Linked list of connected handlers
		_proxyHandler = nil,        -- Optional proxy for wrapping RBXScriptSignals
		_yieldedThreads = nil,      -- Set of threads waiting on Wait()
	}, Signal)

	return self
end

function Signal.Wrap<T...>(rbxScriptSignal: RBXScriptSignal): Signal<T...>
	assert(
		typeof(rbxScriptSignal) == "RBXScriptSignal",
		"Argument #1 to Signal.Wrap must be a RBXScriptSignal; got " .. typeof(rbxScriptSignal)
	)

	local signal = Signal.new()
	signal._proxyHandler = rbxScriptSignal:Connect(function(...)
		signal:Fire(...)
	end)

	return signal
end

function Signal.Is(obj: any): boolean
	return type(obj) == "table" and getmetatable(obj) == Signal
end

--[=[
	@method Connect
	@within Signal
	Subscribes a handler function to this signal. Returns a connection object that can be disconnected.
	@generic T...
	@param fn (T...) -> () -- The handler function to call when the signal fires
	@return Connection -- A connection that can be disconnected
]=]
function Signal:Connect(fn)
	local connection = setmetatable({
		Connected = true,
		_signal = self,      -- Reference back to parent signal
		_fn = fn,            -- The handler function
		_next = false,       -- Linked list pointer
	}, Connection)

	-- Insert at the head of the handler linked list (O(1) insertion)
	if self._handlerListHead then
		connection._next = self._handlerListHead
		self._handlerListHead = connection
	else
		self._handlerListHead = connection
	end

	return connection
end

function Signal:ConnectOnce(fn)
	return self:Once(fn)
end

--[=[
	@method Once
	@within Signal
	Subscribes a handler function that fires only once, then automatically disconnects.
	@generic T...
	@param fn (T...) -> () -- The handler function to call once
	@return Connection -- A connection that can be manually disconnected before firing
]=]
function Signal:Once(fn)
	local connection
	local done = false

	-- Wrap the user handler to auto-disconnect after the first fire
	connection = self:Connect(function(...)
		if done then
			return
		end

		-- Mark as fired and prevent re-entrance
		done = true
		connection:Disconnect()
		-- Call the original handler with the event arguments
		fn(...)
	end)

	return connection
end

function Signal:GetConnections()
	local items = {}

	local item = self._handlerListHead
	while item do
		table.insert(items, item)
		item = item._next
	end

	return items
end

--[=[
	@method DisconnectAll
	@within Signal
	Disconnects all connected handlers and cancels any threads currently waiting on Wait().
]=]
function Signal:DisconnectAll()
	-- Step 1: Mark all handlers as disconnected
	local item = self._handlerListHead
	while item do
		item.Connected = false
		item = item._next
	end
	self._handlerListHead = false

	-- Step 2: Cancel any threads waiting on Wait() and warn about the cancellation
	local yieldedThreads = rawget(self, "_yieldedThreads")
	if yieldedThreads then
		for thread in yieldedThreads do
			if coroutine.status(thread) == "suspended" then
				warn(debug.traceback(thread, "signal disconnected; yielded thread cancelled", 2))
				task.cancel(thread)
			end
		end
		table.clear(self._yieldedThreads)
	end
end

--[=[
	@method Fire
	@within Signal
	Fires the signal to all connected handlers with the given arguments. Handlers run asynchronously.
	@generic T...
	@param ... T... -- Arguments to pass to all handlers
]=]
function Signal:Fire(...)
	-- Step 1: Iterate through all connected handlers
	local item = self._handlerListHead
	while item do
		if item.Connected then
			-- Step 2: Reuse or create a runner thread for this handler
			if not freeRunnerThread then
				freeRunnerThread = coroutine.create(runEventHandlerInFreeThread)
			end
			-- Step 3: Spawn the handler on the reusable thread (allows yielding in handlers)
			task.spawn(freeRunnerThread, item._fn, ...)
		end
		item = item._next
	end
end

function Signal:FireDeferred(...)
	local item = self._handlerListHead
	while item do
		local conn = item
		task.defer(function(...)
			if conn.Connected then
				conn._fn(...)
			end
		end, ...)
		item = item._next
	end
end

--[=[
	@method Wait
	@within Signal
	Yields the current thread until the signal fires, then returns the arguments passed to Fire().
	@generic T...
	@return T... -- The arguments passed to Fire()
	@yields
]=]
function Signal:Wait()
	-- Step 1: Initialize the yielded threads set on first wait
	local yieldedThreads = rawget(self, "_yieldedThreads")
	if not yieldedThreads then
		yieldedThreads = {}
		rawset(self, "_yieldedThreads", yieldedThreads)
	end

	-- Step 2: Register the current thread as waiting
	local thread = coroutine.running()
	yieldedThreads[thread] = true

	-- Step 3: Connect a one-shot handler that resumes this thread when the signal fires
	self:Once(function(...)
		yieldedThreads[thread] = nil
		task.spawn(thread, ...)
	end)

	-- Step 4: Yield until the handler resumes us with the signal's arguments
	return coroutine.yield()
end

--[=[
	@method Destroy
	@within Signal
	Disconnects all handlers and cleans up any proxy connections to RBXScriptSignals.
]=]
function Signal:Destroy()
	-- Step 1: Disconnect all handlers and cancel waiting threads
	self:DisconnectAll()

	-- Step 2: If this signal is wrapping an RBXScriptSignal, disconnect the proxy
	local proxyHandler = rawget(self, "_proxyHandler")
	if proxyHandler then
		proxyHandler:Disconnect()
	end
end

-- Make signal strict
setmetatable(Signal, {
	__index = function(_tb, key)
		error(("Attempt to get Signal::%s (not a valid member)"):format(tostring(key)), 2)
	end,
	__newindex = function(_tb, key, _value)
		error(("Attempt to set Signal::%s (not a valid member)"):format(tostring(key)), 2)
	end,
})

return table.freeze({
	new = Signal.new,
	Wrap = Signal.Wrap,
	Is = Signal.Is,
})