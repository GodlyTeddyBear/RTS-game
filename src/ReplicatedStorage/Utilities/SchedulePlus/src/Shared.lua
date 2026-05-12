--!strict

local Types = require(script.Parent.Types)

local Shared = {}

export type THandleState = {
	Cancelled: boolean,
	Pending: boolean,
	Running: boolean,
	Completed: boolean,
	Paused: boolean,
}

export type THandleHooks = {
	OnCancel: (() -> ())?,
	OnPause: (() -> ())?,
	OnResume: (() -> ())?,
	OnFlush: (() -> ())?,
}

function Shared.AssertNonNegativeNumber(value: number, name: string)
	assert(type(value) == "number", string.format("%s must be a number", name))
	assert(value >= 0, string.format("%s must be >= 0", name))
end

function Shared.AssertPositiveNumber(value: number, name: string)
	assert(type(value) == "number", string.format("%s must be a number", name))
	assert(value > 0, string.format("%s must be > 0", name))
end

function Shared.AssertFunction(callback: any, name: string)
	assert(type(callback) == "function", string.format("%s must be a function", name))
end

function Shared.ShallowCopy<T>(list: { T }): { T }
	local nextList = table.create(#list)
	for index, value in ipairs(list) do
		nextList[index] = value
	end
	return nextList
end

function Shared.CreateExecutionHandle(hooks: THandleHooks?): (Types.TExecutionHandle, THandleState)
	local state = {
		Cancelled = false,
		Pending = true,
		Running = false,
		Completed = false,
		Paused = false,
	}

	local handle = {} :: any

	local function cancel()
		if state.Cancelled or state.Completed then
			return
		end

		state.Cancelled = true
		state.Pending = false
		state.Running = false

		if hooks and hooks.OnCancel then
			hooks.OnCancel()
		end
	end

	handle.Cancel = function()
		cancel()
	end

	handle.Destroy = function()
		cancel()
	end

	handle.IsCancelled = function()
		return state.Cancelled
	end

	handle.IsPending = function()
		return state.Pending
	end

	handle.IsRunning = function()
		return state.Running
	end

	handle.IsCompleted = function()
		return state.Completed
	end

	if hooks and hooks.OnFlush then
		handle.Flush = function()
			if state.Cancelled or state.Completed then
				return
			end

			hooks.OnFlush()
		end
	end

	if hooks and hooks.OnPause then
		handle.Pause = function()
			if state.Cancelled or state.Completed or state.Paused then
				return
			end

			state.Paused = true
			hooks.OnPause()
		end
	end

	if hooks and hooks.OnResume then
		handle.Resume = function()
			if state.Cancelled or state.Completed or not state.Paused then
				return
			end

			state.Paused = false
			hooks.OnResume()
		end
	end

	if hooks and (hooks.OnPause or hooks.OnResume) then
		handle.IsPaused = function()
			return state.Paused
		end
	end

	return handle :: Types.TExecutionHandle, state
end

return Shared
