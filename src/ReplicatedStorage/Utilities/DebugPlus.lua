--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DebugConfig = require(ReplicatedStorage.Config.DebugConfig)

local profileBegin = debug.profilebegin
local profileEnd = debug.profileend

local function _noop()
	return
end

local function _assertLabel(label: string)
	assert(type(label) == "string" and label ~= "", "DebugPlus label must be a non-empty string")
end

local function _assertCallback(callback: any)
	assert(type(callback) == "function", "DebugPlus callback must be a function")
end

local function _composeLabel(parentLabel: string, childLabel: string): string
	_assertLabel(childLabel)
	return `{parentLabel}:{childLabel}`
end

local function _beginScope(label: string): () -> ()
	profileBegin(label)

	local closed = false
	return function()
		if closed then
			return
		end

		closed = true
		profileEnd()
	end
end

type TPackedResult = {
	[number]: any,
	n: number,
}

export type TScope = {
	close: (self: TScope) -> (),
	step: (self: TScope, stepLabel: string, callback: () -> any) -> any,
}

type TScopeInternal = TScope & {
	_closeFn: () -> (),
	_enabled: boolean?,
	_label: string,
}

local DebugPlus = {}

function DebugPlus.isEnabled(localEnabled: boolean?): boolean
	return DebugConfig.ENABLED == true and localEnabled == true
end

function DebugPlus.begin(label: string, enabled: boolean?): () -> ()
	_assertLabel(label)

	-- Profiling scopes must begin and end on the same Luau thread or callback.
	-- For async or parallel work, call begin/end inside the spawned or parallel body.
	if not DebugPlus.isEnabled(enabled) then
		return _noop
	end

	return _beginScope(label)
end

function DebugPlus.wrap<TArgs..., TReturn...>(
	label: string,
	callback: (TArgs...) -> TReturn...,
	enabled: boolean?
): (TArgs...) -> TReturn...
	_assertLabel(label)
	_assertCallback(callback)

	if not DebugPlus.isEnabled(enabled) then
		return callback
	end

	return function(...: TArgs...): TReturn...
		local args = table.pack(...)
		local close = _beginScope(label)
		local packed: TPackedResult = table.pack(xpcall(function()
			return callback(table.unpack(args, 1, args.n))
		end, debug.traceback))
		close()

		if not packed[1] then
			error(packed[2], 0)
		end

		local unpacked: any = table.unpack(packed, 2, packed.n)
		return unpacked
	end
end

function DebugPlus.profile<T...>(label: string, callback: () -> T..., enabled: boolean?): T...
	local profiledCallback = DebugPlus.wrap(label, callback, enabled)
	return profiledCallback()
end

function DebugPlus.step<T...>(label: string, enabled: boolean?, callback: () -> T...): T...
	return DebugPlus.profile(label, callback, enabled)
end

function DebugPlus.scope(label: string, enabled: boolean?): TScope
	_assertLabel(label)

	local scope = {
		_closeFn = DebugPlus.begin(label, enabled),
		_enabled = enabled,
		_label = label,
	} :: TScopeInternal

	function scope:close()
		self._closeFn()
	end

	function scope:step(stepLabel: string, callback: () -> any)
		return DebugPlus.step(_composeLabel(self._label, stepLabel), self._enabled, callback)
	end

	return scope
end

function DebugPlus.spawn<TArgs..., TReturn...>(
	label: string,
	callback: (TArgs...) -> TReturn...,
	enabled: boolean?,
	...: TArgs...
): thread
	return task.spawn(DebugPlus.wrap(label, callback, enabled), ...)
end

function DebugPlus.defer<TArgs..., TReturn...>(
	label: string,
	callback: (TArgs...) -> TReturn...,
	enabled: boolean?,
	...: TArgs...
): thread
	return task.defer(DebugPlus.wrap(label, callback, enabled), ...)
end

return table.freeze(DebugPlus)
