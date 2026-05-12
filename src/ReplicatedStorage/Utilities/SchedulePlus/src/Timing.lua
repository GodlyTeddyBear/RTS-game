--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = require(script.Parent.Shared)
local Types = require(script.Parent.Types)

local UtilitiesFolder = ReplicatedStorage.Utilities
local Throttle = require(UtilitiesFolder.Throttle)
local Sandwich = require(UtilitiesFolder.Sandwich)

local debounceTrailingEntries: { [any]: Types.TDebounceEntry } = {}
local debounceLeadingWindows: {
	[key: any]: {
		Handle: Types.TExecutionHandle,
	},
} = {}
local throttleTrailingWindows: {
	[key: any]: {
		Handle: Types.TExecutionHandle,
		LatestArgs: { any },
	},
} = {}
local throttleLeadingTrailingWindows: {
	[key: any]: {
		WindowOpen: boolean,
		TrailingArgs: { any }?,
		Handle: Types.TExecutionHandle,
	},
} = {}

local Timing = {}

local function _RunCallback<A...>(state: Shared.THandleState, callback: (A...) -> (), ...: A...)
	if state.Cancelled then
		return
	end

	state.Pending = false
	state.Running = true
	callback(...)

	if state.Cancelled then
		return
	end

	state.Running = false
	state.Completed = true
end

local function _CreateTrailingThrottleHandle<T, A...>(key: T, delay: number, callback: (T, A...) -> (), ...: A...): Types.TExecutionHandle
	local thread: thread? = nil
	local handle, state = Shared.CreateExecutionHandle({
		OnCancel = function()
			if thread ~= nil then
				task.cancel(thread)
			end
			throttleTrailingWindows[key] = nil
		end,
	})

	throttleTrailingWindows[key] = {
		Handle = handle,
		LatestArgs = { ... },
	}

	thread = task.delay(delay, function()
		local entry = throttleTrailingWindows[key]
		if entry == nil or state.Cancelled then
			return
		end

		throttleTrailingWindows[key] = nil
		_RunCallback(state, callback, key, unpack(entry.LatestArgs))
	end)

	return handle
end

function Timing.Delay<A...>(duration: number, callback: (A...) -> (), ...: A...): Types.TExecutionHandle
	Shared.AssertNonNegativeNumber(duration, "duration")
	Shared.AssertFunction(callback, "callback")

	local thread: thread? = nil
	local handle, state = Shared.CreateExecutionHandle({
		OnCancel = function()
			if thread ~= nil then
				task.cancel(thread)
			end
		end,
	})

	thread = task.delay(duration, function(...: A...)
		_RunCallback(state, callback, ...)
	end, ...)

	return handle
end

function Timing.DelayUntil(predicate: () -> boolean, config: Types.TDelayUntilConfig?): Types.TExecutionHandle
	Shared.AssertFunction(predicate, "predicate")

	local resolvedConfig = config or {}
	local callback = resolvedConfig.Callback or function() end
	local pollInterval = resolvedConfig.PollInterval or 0.03
	local timeoutSeconds = resolvedConfig.TimeoutSeconds

	Shared.AssertFunction(callback, "config.Callback")
	Shared.AssertNonNegativeNumber(pollInterval, "config.PollInterval")

	if timeoutSeconds ~= nil then
		Shared.AssertNonNegativeNumber(timeoutSeconds, "config.TimeoutSeconds")
	end

	local startedAt = os.clock()
	local handle, state = Shared.CreateExecutionHandle()

	task.spawn(function()
		while not state.Cancelled do
			if predicate() then
				_RunCallback(state, callback)
				return
			end

			if timeoutSeconds ~= nil and (os.clock() - startedAt) >= timeoutSeconds then
				handle:Cancel()
				return
			end

			task.wait(pollInterval)
		end
	end)

	return handle
end

function Timing.NextFrame<A...>(callback: (A...) -> (), ...: A...): Types.TExecutionHandle
	Shared.AssertFunction(callback, "callback")
	local args = { ... }

	local connection: RBXScriptConnection? = nil
	local handle, state = Shared.CreateExecutionHandle({
		OnCancel = function()
			if connection ~= nil then
				connection:Disconnect()
			end
		end,
	})

	connection = RunService.Heartbeat:Connect(function()
		if connection ~= nil then
			connection:Disconnect()
			connection = nil
		end

		_RunCallback(state, callback, unpack(args))
	end)

	return handle
end

function Timing.AfterFrames<A...>(frameCount: number, callback: (A...) -> (), ...: A...): Types.TExecutionHandle
	Shared.AssertNonNegativeNumber(frameCount, "frameCount")
	Shared.AssertFunction(callback, "callback")
	local args = { ... }

	local remainingFrames = frameCount + 1
	local connection: RBXScriptConnection? = nil
	local handle, state = Shared.CreateExecutionHandle({
		OnCancel = function()
			if connection ~= nil then
				connection:Disconnect()
			end
		end,
	})

	connection = RunService.Heartbeat:Connect(function()
		remainingFrames -= 1
		if remainingFrames > 0 then
			return
		end

		if connection ~= nil then
			connection:Disconnect()
			connection = nil
		end

		_RunCallback(state, callback, unpack(args))
	end)

	return handle
end

function Timing.Interval<A...>(period: number, callback: (A...) -> boolean?, ...: A...): Types.TExecutionHandle
	Shared.AssertNonNegativeNumber(period, "period")
	Shared.AssertFunction(callback, "callback")

	local handle, state = Shared.CreateExecutionHandle()
	local thread = Sandwich.interval(period, function(...: A...)
		if state.Cancelled then
			return true
		end

		state.Pending = false
		state.Running = true
		local shouldStop = callback(...)
		state.Running = false

		if shouldStop ~= nil then
			state.Completed = true
			return true
		end

		state.Pending = true
		return nil
	end, ...)

	local cancel = handle.Cancel
	handle.Cancel = function(self)
		task.cancel(thread)
		cancel(self)
	end
	handle.Destroy = handle.Cancel

	return handle
end

function Timing.IntervalImmediate<A...>(period: number, callback: (A...) -> boolean?, ...: A...): Types.TExecutionHandle
	Shared.AssertNonNegativeNumber(period, "period")
	Shared.AssertFunction(callback, "callback")

	local stopImmediately = callback(...)
	if stopImmediately ~= nil then
		local handle, state = Shared.CreateExecutionHandle()
		state.Pending = false
		state.Completed = true
		return handle
	end

	return Timing.Interval(period, callback, ...)
end

function Timing.Tick(event: any, frequency: number, callback: (...any) -> ()): Types.TExecutionHandle
	Shared.AssertPositiveNumber(frequency, "frequency")
	Shared.AssertFunction(callback, "callback")

	local connection = Sandwich.tick(event, frequency, callback)
	local handle, state = Shared.CreateExecutionHandle({
		OnCancel = function()
			connection:Disconnect()
		end,
	})

	state.Pending = false
	return handle
end

function Timing.TickWhen(
	event: any,
	predicate: (...any) -> boolean,
	frequencyOrCallback: number | ((...any) -> ())?,
	callback: ((...any) -> ())?
): Types.TExecutionHandle
	Shared.AssertFunction(predicate, "predicate")

	local frequency: number? = nil
	local resolvedCallback: (...any) -> ()

	if callback == nil then
		resolvedCallback = frequencyOrCallback :: (...any) -> ()
	else
		frequency = frequencyOrCallback :: number
		resolvedCallback = callback
	end

	Shared.AssertFunction(resolvedCallback, "callback")

	local function wrappedCallback(...)
		if predicate(...) then
			resolvedCallback(...)
		end
	end

	if frequency == nil then
		local connection = event:Connect(wrappedCallback)
		local handle, state = Shared.CreateExecutionHandle({
			OnCancel = function()
				connection:Disconnect()
			end,
		})
		state.Pending = false
		return handle
	end

	return Timing.Tick(event, frequency, wrappedCallback)
end

function Timing.ThrottleLeading<T, A...>(key: T, delay: number, callback: (T, A...) -> (), ...: A...): boolean
	Shared.AssertNonNegativeNumber(delay, "delay")
	Shared.AssertFunction(callback, "callback")

	return Throttle(key, delay, callback, ...)
end

function Timing.Throttle<T, A...>(key: T, delay: number, callback: (T, A...) -> (), ...: A...): boolean
	return Timing.ThrottleLeading(key, delay, callback, ...)
end

function Timing.ThrottleTrailing<T, A...>(key: T, delay: number, callback: (T, A...) -> (), ...: A...): Types.TExecutionHandle
	Shared.AssertNonNegativeNumber(delay, "delay")
	Shared.AssertFunction(callback, "callback")

	local existing = throttleTrailingWindows[key]
	if existing ~= nil then
		existing.LatestArgs = { ... }
		return existing.Handle
	end

	return _CreateTrailingThrottleHandle(key, delay, callback, ...)
end

function Timing.ThrottleLeadingTrailing<T, A...>(
	key: T,
	delay: number,
	callback: (T, A...) -> (),
	...: A...
): Types.TExecutionHandle
	Shared.AssertNonNegativeNumber(delay, "delay")
	Shared.AssertFunction(callback, "callback")

	local existing = throttleLeadingTrailingWindows[key]
	if existing == nil then
		callback(key, ...)

		local thread: thread? = nil
		local handle, state = Shared.CreateExecutionHandle({
			OnCancel = function()
				if thread ~= nil then
					task.cancel(thread)
				end
				throttleLeadingTrailingWindows[key] = nil
			end,
		})

		throttleLeadingTrailingWindows[key] = {
			WindowOpen = true,
			TrailingArgs = nil,
			Handle = handle,
		}

		thread = task.delay(delay, function()
			local entry = throttleLeadingTrailingWindows[key]
			if entry == nil or state.Cancelled then
				return
			end

			if entry.TrailingArgs ~= nil then
				_RunCallback(state, callback, key, unpack(entry.TrailingArgs))
			else
				state.Pending = false
				state.Completed = true
			end

			throttleLeadingTrailingWindows[key] = nil
		end)

		return handle
	end

	existing.TrailingArgs = { ... }
	return existing.Handle
end

function Timing.DebounceTrailing<T, A...>(key: T, delay: number, callback: (T, A...) -> (), ...: A...): Types.TExecutionHandle
	Shared.AssertNonNegativeNumber(delay, "delay")
	Shared.AssertFunction(callback, "callback")

	local previousEntry = debounceTrailingEntries[key]
	if previousEntry then
		previousEntry.Handle:Cancel()
	end

	local thread: thread? = nil
	local handle, state = Shared.CreateExecutionHandle({
		OnCancel = function()
			if thread ~= nil then
				task.cancel(thread)
			end

			local currentEntry = debounceTrailingEntries[key]
			if currentEntry and currentEntry.Handle == handle then
				debounceTrailingEntries[key] = nil
			end
		end,
	})

	thread = task.delay(delay, function(...: A...)
		local currentEntry = debounceTrailingEntries[key]
		if currentEntry and currentEntry.Handle == handle then
			debounceTrailingEntries[key] = nil
		end

		_RunCallback(state, callback, key, ...)
	end, ...)

	debounceTrailingEntries[key] = {
		Handle = handle,
	}

	return handle
end

function Timing.DebounceLeading<T, A...>(key: T, delay: number, callback: (T, A...) -> (), ...: A...): Types.TExecutionHandle
	Shared.AssertNonNegativeNumber(delay, "delay")
	Shared.AssertFunction(callback, "callback")

	local existing = debounceLeadingWindows[key]
	local shouldInvokeImmediately = existing == nil
	if existing ~= nil then
		existing.Handle:Cancel()
	end

	local thread: thread? = nil
	local handle, state = Shared.CreateExecutionHandle({
		OnCancel = function()
			if thread ~= nil then
				task.cancel(thread)
			end
			debounceLeadingWindows[key] = nil
		end,
	})

	if shouldInvokeImmediately then
		callback(key, ...)
		state.Pending = true
	end

	thread = task.delay(delay, function()
		debounceLeadingWindows[key] = nil
		state.Pending = false
		state.Completed = true
	end)

	debounceLeadingWindows[key] = {
		Handle = handle,
	}

	return handle
end

function Timing.Debounce<T, A...>(key: T, delay: number, callback: (T, A...) -> (), ...: A...): Types.TExecutionHandle
	return Timing.DebounceTrailing(key, delay, callback, ...)
end

return Timing
