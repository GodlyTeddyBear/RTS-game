--!strict

--[=[
	@class Result
	Structured error handling with exception propagation.

	**Failure categories:**
	- Business failure (`Err`) — expected, typed, recoverable. `orElse` fires. Logged as warn.
	- Defect (`Defect`) — unexpected crash. `orElse` skips. Logged as error with traceback.

	The distinction matters for rollback logic: `orElse` handlers (e.g. gold rollback on
	failed inventory add) should only fire when the operation failed expectedly — not
	when it crashed. Defects bypass `orElse` and propagate directly to `Catch`.

	**Constructors** (return Result — chainable):
	- `Ok(value)` — Wrap a success value
	- `Err(type, message, data?)` — Wrap a business failure with structured context
	- `Defect(message, traceback?)` — Wrap an unexpected crash (nil access, raw error(), etc.)
	- `TryAll(...)` — Accumulate multiple Results; Ok with all values or Err with all failures
	- `fromPcall(errType, fn, ...)` — Convert a pcall-style Roblox API call into a Result
	- `fromNilable(value, errType, msg, data?)` — Convert a nil-able value into a Result
	- `Catch(fn, label, failureHandler, ...)` — xpcall boundary; returns Result (never throws)

	**Throwable** (use inside Catch — return plain values, throw on failure):
	- `Try(result)` — Unwrap Ok value or throw Err
	- `Ensure(condition, type, msg)` — Assert truthy or throw Err; returns condition
	- `RequirePath(root, ...)` — Walk nested keys or throw Err; returns final value

	**Chainable methods** (return Result — can continue chaining):
	- `result:andThen(fn)` — Transform Ok value (fn must return Result); pass Err through
	- `result:orElse(fn)` — Recover from business Err (fn must return Result); pass Ok and defects through
	- `result:tapError(fn)` — Side-effect on any failure (Err or Defect); pass all results through unchanged
	- `result:tap(fn)` — Side-effect on Ok value; pass all results through unchanged
	- `result:tapBoth(onOk, onErr)` — Side-effect on any outcome; pass all results through unchanged
	- `result:mapError(fn)` — Transform business Err (fn must return Err); pass Ok and defects through
	- `result:filter(predicate, errType, msg, data?)` — Reject Ok value if predicate is falsy; pass Err and defects through
	- `result:filterOrElse(predicate, fn)` — Reject Ok value with error built from the value itself; pass Err and defects through

	**Terminal methods** (return plain values — end the chain):
	- `result:map(fn)` — Unwrap Ok + transform; throws on Err (like Try + transform)
	- `result:unwrapOr(default)` — Extract Ok value or return default (safe, never throws)

	**Combinators** (operate on multiple Results or functions):
	- `Result.zip(resultA, resultB)` — Combine two Results into Ok({a, b}); short-circuits on first Err
	- `Result.zipWith(resultA, resultB, fn)` — Combine two Results with a function; short-circuits on first Err
	- `Result.traverse(items, fn)` — Map fn over a list, accumulate all Results (like TryAll over a mapped list)
	- `Result.retry(fn, options)` — Retry a yielding function up to maxAttempts times with optional delay

	**Async** (return Promises — bridge between Result and Promise systems):
	- `Result.timeout(fn, seconds, errType?)` — Run a yielding function; return Err if it exceeds the duration
	- `Result.race(fns)` — Run multiple yielding functions; resolve with the first to finish
	- `Result.all(fns)` — Run multiple yielding functions concurrently; collect all Results

	**Structured resource management** (guaranteed cleanup on any outcome):
	- `Result.scoped(fn)` — Run fn with a Scope; cleanup always fires on exit (Ok, Err, or Defect)
	- `Result.acquireRelease(acquire, release, use)` — Acquire a resource, use it, release it — guaranteed
	- `scope:add(resource, cleanupFn)` — Register any resource with a custom cleanup function
	- `scope:addJanitorItem(obj, methodName?)` — Register any Janitor-trackable object (Instance, connection, etc.)
	- `scope:addPromise(promise)` — Register a Promise; cancelled automatically if the scope exits early

	**Inspection** (pause the chain to inspect without consequence):
	- `Result.sandbox(result)` — Wrap any Result in Ok — makes it inert, safe to inspect
	- `Result.unsandbox(sandboxed)` — Unwrap back into the error channel — propagation resumes

	**Control flow** (pure control flow — no error handling):
	- `Result.guard(condition, returnValue?)` — Exit the current gen block early if condition is falsy
	- `Result.gen(fn, ...)` — Run fn in a coroutine; returns fn's return value or guard's returnValue

	**Chaining reference:**
	```
	result:andThen(fn)         →  Result  →  chainable
	result:orElse(fn)          →  Result  →  chainable (skips defects)
	result:tapError(fn)        →  Result  →  chainable (fires on Err + Defect; side-effect only)
	result:tap(fn)             →  Result  →  chainable (fires on Ok only; side-effect only)
	result:tapBoth(ok, err)    →  Result  →  chainable (fires on any outcome; side-effect only)
	result:mapError(fn)        →  Result  →  chainable (fires on Err only; skips Ok and defects)
	result:filter(pred)        →  Result  →  chainable (fires on Ok only; skips Err and defects)
	result:filterOrElse(p, fn) →  Result  →  chainable (fires on Ok only; error built from value)
	result:map(fn)             →  value   →  terminal (throws on Err)
	result:unwrapOr(v)         →  value   →  terminal (safe)
	```

	Do NOT chain off `Try()`, `map()`, or `unwrapOr()` — they return plain values.

	**Layer usage:**
	- Value Objects — `assert()` for programmer errors (unchanged)
	- Domain Validators — Return Results. Use `TryAll()` to collect all validation errors.
	- Application — Use `Try()` to unwrap Results. Keeps orchestration clean and linear.
	- Context (Knit) — Use `Catch()` as the single error boundary with a failure handler.
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Promise = require(ReplicatedStorage.Packages.Promise)
local Janitor = require(ReplicatedStorage.Packages.Janitor)

local Result = {}

-- Internal logger — defaults to warn, replaced by LogContext at runtime

local _logger: ((level: string, label: string, err: any) -> ())? = nil
local _successLogger: ((label: string, message: string, data: { [string]: any }?) -> ())? = nil
local _eventLogger: ((label: string, message: string, data: { [string]: any }?) -> ())? = nil

--[=[
	Registers a custom log handler. Called once from Runtime.server.lua after Knit.Start().
	The handler receives the log level, a label string, and the Err table.
	If not set, errors fall back to warn().
	@within Result
	@param fn function -- (level: string, label: string, err: Err) -> ()
]=]
function Result.SetLogger(fn: (level: string, label: string, err: any) -> ())
	_logger = fn
end

--[=[
	Registers a success log handler. Called once from LogContext:KnitInit().
	@within Result
	@param fn function -- (label: string, message: string, data: { [string]: any }?) -> ()
]=]
function Result.SetSuccessLogger(fn: (label: string, message: string, data: { [string]: any }?) -> ())
	_successLogger = fn
end

--[=[
	Registers an event log handler. Called once from LogContext:KnitInit().
	@within Result
	@param fn function -- (label: string, message: string, data: { [string]: any }?) -> ()
]=]
function Result.SetEventLogger(fn: (label: string, message: string, data: { [string]: any }?) -> ())
	_eventLogger = fn
end

--[=[
	Optionally records a success milestone. No-op if no success logger is registered.
	@within Result
	@param label string -- "Context:Service" format, e.g. "Inventory:AddItem"
	@param message string -- Human-readable description of what succeeded
	@param data table? -- Optional contextual data
]=]
function Result.MentionSuccess(label: string, message: string, data: { [string]: any }?)
	local successLogger = _successLogger
	if successLogger then
		task.spawn(function()
			successLogger(label, message, data)
		end)
	end
end

--[=[
	Optionally records an event bus milestone. No-op if no event logger is registered.
	@within Result
	@param label string -- "Context:Service" format, e.g. "Events:Emit"
	@param message string -- Human-readable description of the event operation
	@param data table? -- Optional contextual data
]=]
function Result.MentionEvent(label: string, message: string, data: { [string]: any }?)
	local eventLogger = _eventLogger
	if eventLogger then
		task.spawn(function()
			eventLogger(label, message, data)
		end)
	end
end

local function _log(level: string, label: string, err: any)
	if _logger then
		_logger(level, label, err)
	else
		warn(("[" .. label .. "]"), err.type, err.message)
	end
end

--[=[
	Optionally records an issue milestone through the standard error logger.
	Use when a function needs to report a failure but is not returning a Result.
	@within Result
	@param label string -- "Context:Service" format, e.g. "Combat:Attack:ActivateHitbox"
	@param message string -- Human-readable description of what failed
	@param data table? -- Optional contextual data
	@param errType string? -- Optional issue type; defaults to "MentionError"
]=]
function Result.MentionError(label: string, message: string, data: { [string]: any }?, errType: string?)
	task.spawn(function()
		_log("warn", label, {
			type = errType or "MentionError",
			message = message,
			data = data,
		})
	end)
end

-- Types

type ResultChain = {
	andThen: (self: any, fn: (any) -> any) -> any,
	orElse: (self: any, fn: (any) -> any) -> any,
	tapError: (self: any, fn: (any) -> ()) -> any,
	mapError: (self: any, fn: (any) -> any) -> any,
	filter: (self: any, predicate: (any) -> boolean, errType: string, message: string, data: ({ [string]: any })?) -> any,
	filterOrElse: (self: any, predicate: (any) -> boolean, fn: (any) -> any) -> any,
	tap: (self: any, fn: (any) -> ()) -> any,
	tapBoth: (self: any, onOk: (any) -> (), onErr: (any) -> ()) -> any,
	map: (self: any, fn: (any) -> any) -> any,
	unwrapOr: (self: any, default: any) -> any,
}

export type Ok<T> = ResultChain & {
	_isResult: true,
	success: true,
	value: T,
}

export type Err = ResultChain & {
	_isResult: true,
	success: false,
	type: string,
	message: string,
	data: { [string]: any }?,
	traceback: string?,
}

export type Result<T> = Ok<T> | Err

-- Method metatable shared by all Ok and Err instances

local ResultMeta = {}
ResultMeta.__index = ResultMeta

--[=[
	Applies fn to the Ok value and returns its Result.
	If the result is Err, passes it through unchanged without calling fn.
	Use to transform a success value while staying inside the Result system.
	@within Result
	@param fn function -- Transformation applied to the Ok value; must return a Result
	@return Result -- The Result returned by fn, or the original Err
]=]
function ResultMeta:andThen(fn: (any) -> Result<any>): Result<any>
	if not self.success then
		return self
	end
	return fn(self.value)
end

--[=[
	Applies fn to the Err and returns its Result.
	If the result is Ok or a defect, passes it through unchanged without calling fn.
	Use to recover from an expected business failure inline without propagating it up.
	Defects (crashes) are never passed to fn — they bypass recovery and propagate to Catch.
	@within Result
	@param fn function -- Recovery function receiving the Err; return Ok to continue, Err to re-fail
	@return Result -- The original Ok or defect unchanged, or the Result returned by fn
]=]
function ResultMeta:orElse(fn: (Err) -> Result<any>): Result<any>
	if self.success or (self :: any).isDefect then
		return self
	end
	return fn(self :: any)
end

--[=[
	Calls fn with self as a side effect and returns self unchanged.
	Fires on any failure — both business Err and Defect.
	Does not fire on Ok.
	Use to log, track, or notify on any error without altering the chain.
	@within Result
	@param fn function -- Side-effect callback receiving the Err or Defect; return value is ignored
	@return Result -- The original result, always unchanged
]=]
function ResultMeta:tapError(fn: (any) -> ()): Result<any>
	if not self.success then
		fn(self)
	end
	return self
end

--[=[
	Applies fn to a business Err and returns the Err fn provides.
	Does not fire on Ok or Defect — both pass through unchanged.
	Use to retype or enrich an Err mid-chain (e.g. translate a domain error to a context-level error).
	fn must return a new Err; returning Ok here is a logic error.
	@within Result
	@param fn function -- Transformation applied to the Err; must return an Err
	@return Result -- The Err returned by fn, or the original Ok/Defect unchanged
]=]
function ResultMeta:mapError(fn: (Err) -> Err): Result<any>
	if not self.success and not (self :: any).isDefect then
		return fn(self :: any)
	end
	return self
end

--[=[
	Runs predicate against the Ok value; converts to Err if predicate is falsy.
	Does not fire on Err or Defect — both pass through unchanged.
	Use to enforce invariants on a success value inline without leaving the chain.
	@within Result
	@param predicate function -- Receives the Ok value; return truthy to keep Ok, falsy to reject
	@param errType string -- Error category used if the predicate fails
	@param message string -- Human-readable description used if the predicate fails
	@param data table? -- Optional contextual data attached to the Err
	@return Result -- Self if Ok and predicate passes, new Err if it fails, or original Err/Defect
]=]
function ResultMeta:filter(predicate: (any) -> boolean, errType: string, message: string, data: ({ [string]: any })?): Result<any>
	if self.success and not predicate(self.value) then
		return Result.Err(errType, message, data)
	end
	return self
end

--[=[
	Runs predicate against the Ok value; converts to Err built from the rejected value if falsy.
	Does not fire on Err or Defect — both pass through unchanged.
	Use when the error message needs to reference the value that was rejected.
	@within Result
	@param predicate function -- Receives the Ok value; return truthy to keep Ok, falsy to reject
	@param fn function -- Receives the rejected Ok value; must return an Err
	@return Result -- Self if Ok and predicate passes, Err from fn if it fails, or original Err/Defect
]=]
function ResultMeta:filterOrElse(predicate: (any) -> boolean, fn: (any) -> Err): Result<any>
	if self.success and not predicate(self.value) then
		return fn(self.value)
	end
	return self
end

--[=[
	Calls fn with the Ok value as a side effect and returns self unchanged.
	Does not fire on Err or Defect — both pass through untouched.
	Use to log or observe a success value mid-chain without altering it.
	@within Result
	@param fn function -- Side-effect callback receiving the Ok value; return value is ignored
	@return Result -- The original result, always unchanged
]=]
function ResultMeta:tap(fn: (any) -> ()): Result<any>
	if self.success then
		fn(self.value)
	end
	return self
end

--[=[
	Calls onOk or onErr as a side effect depending on outcome, then returns self unchanged.
	onOk fires on Ok; onErr fires on both business Err and Defect.
	Use to observe any outcome mid-chain — e.g. always log when an operation completes.
	@within Result
	@param onOk function -- Side-effect on Ok; receives the value; return value is ignored
	@param onErr function -- Side-effect on Err or Defect; receives the failure; return value is ignored
	@return Result -- The original result, always unchanged
]=]
function ResultMeta:tapBoth(onOk: (any) -> (), onErr: (any) -> ()): Result<any>
	if self.success then
		onOk(self.value)
	else
		onErr(self)
	end
	return self
end

--[=[
	Unwraps Ok, applies fn to the value, and returns the plain result.
	If the result is Err, throws it as an exception (like Try).
	Combines Try + transformation in one step. Exits the Result system.
	Use inside Catch boundaries when you need to unwrap and reshape in one call.
	@within Result
	@param fn function -- Transformation applied to the Ok value; returns a plain value
	@return any -- The transformed value (plain, not a Result)
]=]
function ResultMeta:map(fn: (any) -> any): any
	if not self.success then
		error(self)
	end
	return fn(self.value)
end

--[=[
	Extracts the Ok value, or returns default if the result is Err.
	Exits the Result system — the return value is a plain value, not a Result.
	Use when a missing value is acceptable and no further chaining is needed.
	@within Result
	@param default any -- Fallback value returned on Err
	@return any -- The Ok value or default
]=]
function ResultMeta:unwrapOr(default: any): any
	if self.success then
		return self.value
	end
	return default
end

-- System-level error types

Result.Types = table.freeze({
	RuntimeError = "RuntimeError",
	MultipleErrors = "MultipleErrors",
	MissingPath = "MissingPath",
})

-- Constructors

--[=[
	Wraps a success value into a Result.
	@within Result
	@param value any -- The success payload
	@return Ok
]=]
function Result.Ok<T>(value: T): Ok<T>
	return setmetatable({
		_isResult = true,
		success = true,
		value = value,
	}, ResultMeta) :: any
end

--[=[
	Wraps a business failure into a Result with structured context.
	Use for expected, typed failures (e.g. validation rejected, item not found).
	These are recoverable — orElse will fire. Logged as warn by Catch.
	@within Result
	@param errType string -- Error category (e.g. "InsufficientGold", "DataStoreFailed")
	@param message string -- Human-readable description
	@param data table? -- Optional contextual data (e.g. `{ has = 10, needs = 50 }`)
	@return Err
]=]
function Result.Err(errType: string, message: string, data: { [string]: any }?): Err
	return setmetatable({
		_isResult = true,
		success = false,
		type = errType,
		message = message,
		data = data,
	}, ResultMeta) :: any
end

--[=[
	Wraps an unexpected crash into a Result, marking it as a defect.
	Use for nil access, raw error() calls, or any throw that isn't a structured business failure.
	Defects bypass orElse — recovery logic won't fire. Logged as error with traceback by Catch.
	Not intended for direct use in business code — created automatically by Catch and WrapContext.
	@within Result
	@param message string -- The thrown error message
	@param traceback string? -- Stack traceback captured before stack unwind
	@return Err
]=]
function Result.Defect(message: string, traceback: string?): Err
	return setmetatable({
		_isResult = true,
		success = false,
		isDefect = true,
		type = Result.Types.RuntimeError,
		message = message,
		traceback = traceback,
	}, ResultMeta) :: any
end

-- Type check

--[=[
	Returns true if the value is a Result (Ok or Err).
	Useful for defensive checks when a non-Result might be passed accidentally.
	@within Result
	@param value any -- The value to check
	@return boolean
]=]
function Result.isResult(value: any): boolean
	return type(value) == "table" and value._isResult == true
end

-- Unwrap or throw

--[=[
	Unwraps an Ok result and returns its value.
	If the result is an Err, throws it as an exception via error().
	Use inside functions wrapped by Catch() — the error propagates up to the boundary.
	@within Result
	@param result Result -- The result to unwrap
	@return any -- The unwrapped success value
]=]
function Result.Try<T>(result: Result<T>): T
	if not result.success then
		error(result)
	end
	return result.value
end

-- Assert condition or throw

--[=[
	Asserts a condition, returning the value if truthy.
	If falsy, throws a structured Err (caught by Catch like any Try failure).
	Use inside Catch boundaries for inline guard clauses without if/return/end blocks.
	@within Result
	@param condition any -- The condition to check (falsy = failure)
	@param errType string -- Error category
	@param message string -- Human-readable description
	@param data table? -- Optional contextual data
	@return any -- The condition value (pass-through on success)
]=]
function Result.Ensure<T>(condition: T, errType: string, message: string, data: { [string]: any }?): T
	if not condition then
		error(Result.Err(errType, message, data))
	end
	return condition
end

-- Walk nested keys or throw

--[=[
	Walks a chain of string keys on a root table, throwing a structured Err if any
	intermediate key is nil or not a table. Returns the final value.
	Use inside Catch boundaries to validate nested data paths (e.g. profile data).
	Intermediate keys must resolve to tables. The final value can be any non-nil type.
	@within Result
	@param root any -- The root table to walk
	@param ... string -- The keys to traverse in order
	@return any -- The value at the final key
]=]
function Result.RequirePath(root: any, ...: string): any
	local current = root
	for _, key in { ... } do
		if type(current) ~= "table" then
			error(Result.Err("MissingPath", "Expected table at '" .. key .. "', got " .. type(current)))
		end
		local next = current[key]
		if next == nil then
			error(Result.Err("MissingPath", "Path broke at '" .. key .. "'"))
		end
		current = next
	end
	return current
end

-- Accumulate all errors

--[=[
	Evaluates multiple Results and accumulates all errors instead of short-circuiting.
	Returns Ok with all values if every result succeeded.
	Returns Err("MultipleErrors") with all failures in data.errors if any failed.
	If any result is a defect, returns it immediately — defects dominate and are not accumulated.
	Designed for validators that need to report all problems at once.
	@within Result
	@param ... Result -- The results to evaluate
	@return Result -- Ok with values array, Err with accumulated errors, or defect
]=]
function Result.TryAll(...: Result<any>): Result<{ any }>
	local errors = {}
	local values = {}
	for i, result in ipairs({ ... }) do
		if result.success then
			values[i] = result.value
		elseif (result :: any).isDefect then
			return result :: any
		else
			table.insert(errors, result)
		end
	end
	if #errors > 0 then
		local leafErrors = {}
		for _, err in errors do
			if err.type == Result.Types.MultipleErrors and err.data and err.data.errors then
				for _, nested in err.data.errors do
					table.insert(leafErrors, nested)
				end
			else
				table.insert(leafErrors, err)
			end
		end
		local messages = {}
		for _, err in leafErrors do
			table.insert(messages, "[" .. err.type .. "] " .. err.message)
		end
		return Result.Err(Result.Types.MultipleErrors, "Multiple failures: " .. table.concat(messages, "; "), { errors = leafErrors })
	end
	return Result.Ok(values)
end

-- Convert nil-able value into Result

--[=[
	Converts a potentially-nil value into a Result.
	Returns Ok(value) if the value is non-nil; Err otherwise.
	Use to avoid manual if/nil checks when fetching from tables or optional APIs.
	@within Result
	@param value any -- The value to check
	@param errType string -- Error category used if the value is nil
	@param message string -- Human-readable description used if the value is nil
	@param data table? -- Optional contextual data attached to the Err
	@return Result -- Ok wrapping the value, or Err if nil
]=]
function Result.fromNilable(value: any, errType: string, message: string, data: { [string]: any }?): Result<any>
	if value == nil then
		return Result.Err(errType, message, data)
	end
	return Result.Ok(value)
end

-- Convert pcall into Result

--[=[
	Wraps a pcall-style call into a Result.
	Useful for converting Roblox API calls (DataStore, HTTP, etc.) into the Result system.
	@within Result
	@param errType string -- Error category to use if the call fails
	@param fn function -- The function to call
	@param ... any -- Arguments passed to fn
	@return Result -- Ok with the return value, or Err with the pcall error message
]=]
function Result.fromPcall(errType: string, fn: (...any) -> ...any, ...: any): Result<any>
	local ok, result = pcall(fn, ...)
	if not ok then
		return Result.Err(errType, tostring(result))
	end
	return Result.Ok(result)
end

-- Boundary with failure handler

--[=[
	The single error boundary. Calls fn with the provided arguments via xpcall.
	On success: returns Ok wrapping the fn's result.
	On failure: logs via the registered logger (or warn fallback), calls the optional
	failureHandler if provided, then returns the Err or Defect.
	Propagation is automatic by return value — callers detect Err via `not result.success`.
	Use `Try()` inside the fn when you need to unwrap a success value to continue work.
	Plain values returned from fn are automatically wrapped in Ok().

	Two failure categories:
	- Business failure — thrown by `Try()` with a structured Err. Passed through as-is. Logged as warn.
	- Defect — unexpected crash (nil access, raw error()). Wrapped as Defect with traceback. Logged as error.
	@within Result
	@param fn function -- The function to execute
	@param label string -- Identifies the call site in logs, e.g. "Inventory:AddItem"
	@param failureHandler function? -- Optional, called after logging for custom reaction (notify player, fire event, etc.)
	@param ... any -- Arguments passed to fn
	@return Result -- Ok on success, Err or Defect on failure (never throws)
]=]
function Result.Catch<T>(fn: (...any) -> Result<T> | any?, label: string, failureHandler: ((err: Err) -> ())?, ...: any): Result<T>
	local ok, result = xpcall(fn, function(thrown)
		if type(thrown) == "table" and (thrown :: any)._isResult then
			-- Business failure propagated via Try() — pass through as-is
			return thrown
		end
		-- Unexpected crash — wrap as defect with traceback
		return Result.Defect(tostring(thrown), debug.traceback(nil, 2))
	end, ...)

	local function handleFailure(err: any)
		local level = err.isDefect and "error" or "warn"
		_log(level, label, err)
		if failureHandler then
			failureHandler(err)
		end
	end

	if not ok then
		handleFailure(result)
		return result :: any
	end

	-- Auto-wrap plain values so all returns are uniform Results
	if not Result.isResult(result) then
		return Result.Ok(result) :: any
	end

	if not (result :: any).success then
		handleFailure(result)
	end

	return result :: any
end

-- Defect inspection

--[=[
	Wraps any Result in Ok, making it inert — a pause in the chain.
	The wrapped result is now plain data: andThen/orElse/Try will not react to it.
	Use in infrastructure (logging, routing) to inspect a result — including defects —
	without triggering recovery logic or propagation.
	Pair with unsandbox to re-enter the error channel when inspection is done.
	@within Result
	@param result Result -- Any Result (Ok, Err, or Defect)
	@return Ok -- Always Ok; the original result is stored in .value
]=]
function Result.sandbox(result: Result<any>): Ok<Result<any>>
	return Result.Ok(result)
end

--[=[
	Unwraps a sandboxed result back into the error channel.
	If the inner result is a business failure or defect, propagation resumes —
	Try() will throw it, orElse will react (or skip if it's a defect).
	@within Result
	@param sandboxed Ok -- A result previously wrapped by sandbox()
	@return Result -- The original inner result, now live in the chain again
]=]
function Result.unsandbox(sandboxed: Ok<Result<any>>): Result<any>
	return sandboxed.value
end

-- Combinators

--[=[
	Combines two Results into a single Ok({a, b}).
	Short-circuits on the first Err or Defect encountered, left to right.
	Use to pair two independent synchronous Results without nesting andThen.
	@within Result
	@param resultA Result -- First Result
	@param resultB Result -- Second Result
	@return Result -- Ok with `{ value of A, value of B }`, or the first failure
]=]
function Result.zip(resultA: Result<any>, resultB: Result<any>): Result<any>
	if not resultA.success then
		return resultA
	end
	if not resultB.success then
		return resultB
	end
	return Result.Ok({ (resultA :: Ok<any>).value, (resultB :: Ok<any>).value })
end

--[=[
	Combines two Results by applying fn to both Ok values.
	Short-circuits on the first Err or Defect encountered, left to right.
	Use when you want to merge two success values into a single value rather than a table.
	@within Result
	@param resultA Result -- First Result
	@param resultB Result -- Second Result
	@param fn function -- Receives (valueA, valueB); must return a plain value
	@return Result -- Ok with fn's return value, or the first failure
]=]
function Result.zipWith(resultA: Result<any>, resultB: Result<any>, fn: (any, any) -> any): Result<any>
	if not resultA.success then
		return resultA
	end
	if not resultB.success then
		return resultB
	end
	return Result.Ok(fn((resultA :: Ok<any>).value, (resultB :: Ok<any>).value))
end

--[=[
	Maps fn over a list of items and accumulates all Results.
	Equivalent to calling TryAll over the mapped results — all errors are collected, not short-circuited.
	If any result is a Defect, returns it immediately (defects dominate).
	Use to validate or transform a list where you want all failures reported at once.
	@within Result
	@param items table -- The list to map over
	@param fn function -- Applied to each item; must return a Result
	@return Result -- Ok with all values, Err with all accumulated failures, or a Defect
]=]
function Result.traverse(items: { any }, fn: (any) -> Result<any>): Result<any>
	local results = table.create(#items)
	for i, item in items do
		results[i] = fn(item)
	end
	return Result.TryAll(table.unpack(results))
end

--[=[
	Retries a yielding function up to maxAttempts times.
	Stops retrying on Ok or Defect — only business Err triggers a retry.
	Waits delay seconds between attempts if provided.
	@within Result
	@param fn function -- The function to retry; must return a Result
	@param options table -- `{ maxAttempts: number, delay: number? }`
	@return Result -- Ok on success, or the last Err after all attempts are exhausted
]=]
function Result.retry(fn: () -> Result<any>, options: { maxAttempts: number, delay: number? }): Result<any>
	local lastResult: Result<any> = Result.Err("RetryFailed", "No attempts made")
	for _ = 1, options.maxAttempts do
		lastResult = fn()
		if lastResult.success or (lastResult :: any).isDefect then
			return lastResult
		end
		if options.delay then
			task.wait(options.delay)
		end
	end
	return lastResult
end

-- Async

--[=[
	Runs a yielding function and returns a Promise that resolves to a Result.
	If the function does not complete within the given number of seconds, resolves with Err.
	The timed-out thread is not forcibly stopped — it runs to completion in the background.
	@within Result
	@param fn function -- A yielding function; must return a Result
	@param seconds number -- Maximum seconds to wait before resolving with Err
	@param errType string? -- Error type used on timeout; defaults to "Timeout"
	@return any -- Promise that resolves to a Result
]=]
function Result.timeout(fn: () -> Result<any>, seconds: number, errType: string?): any
	return Promise.race({
		Promise.new(function(resolve)
			resolve(fn())
		end),
		Promise.delay(seconds):andThen(function()
			return Promise.resolve(Result.Err(errType or "Timeout", "Operation exceeded " .. seconds .. "s"))
		end),
	})
end

--[=[
	Runs a list of yielding functions concurrently and resolves with the first Result to finish.
	The remaining threads continue running to completion in the background.
	@within Result
	@param fns table -- List of functions; each must return a Result
	@return any -- Promise that resolves to the first Result that completes
]=]
function Result.race(fns: { () -> Result<any> }): any
	local promises = table.create(#fns)
	for i, fn in fns do
		promises[i] = Promise.new(function(resolve)
			resolve(fn())
		end)
	end
	return Promise.race(promises)
end

--[=[
	Runs a list of yielding functions concurrently and collects all Results.
	All functions run in parallel via task.spawn. Resolves once every function has completed.
	The returned Promise resolves to Ok({ result1, result2, ... }) — one Result per function.
	Never rejects — each individual success or failure is captured inside the Results table.
	@within Result
	@param fns table -- List of functions; each must return a Result
	@return any -- Promise that resolves to Ok({ Result, ... })
]=]
function Result.all(fns: { () -> Result<any> }): any
	return Promise.new(function(resolve)
		local count = #fns
		local results: { any } = table.create(count)
		local completed = 0

		for i, fn in fns do
			task.spawn(function()
				results[i] = fn()
				completed += 1
				if completed == count then
					resolve(Result.Ok(results))
				end
			end)
		end
	end)
end

-- Control flow

--[=[
	Exits the current gen block early if condition is falsy.
	Yields returnValue back to gen, which returns it to the caller.
	If condition is truthy, does nothing — execution continues normally.
	Must be called inside a Result.gen block.
	@within Result
	@param condition any -- Falsy triggers early exit
	@param returnValue any? -- Value returned to the gen caller on early exit; defaults to nil
]=]
function Result.guard(condition: any, returnValue: any?)
	-- step 1: condition is already evaluated before guard is called (Lua evaluates args before passing)
	-- step 2: if falsy, yield returnValue out of fn's coroutine back to coroutine.resume in gen
	--         if truthy, do nothing — execution continues past this line normally
	if not condition then
		coroutine.yield(returnValue)
	end
end

--[=[
	Runs fn in a coroutine, enabling Result.guard inside it.
	Suspends the caller until fn fully completes, including any yields inside fn (e.g. task.wait).
	The rest of the game continues normally while the caller is suspended.
	The caller only resumes when fn finishes or a guard fires — nothing else can wake it up.
	Crashes inside fn re-throw and propagate to the nearest Catch boundary.
	@within Result
	@param fn function -- The function to run; may use Result.guard for early exits
	@param ... any -- Arguments passed to fn
	@return any -- fn's return value, or the returnValue passed to the fired guard
]=]
function Result.gen<T>(fn: (...any) -> T, ...: any): T
	-- step 1: capture the calling coroutine so we can resume it later
	local callerCo = coroutine.running()

	-- step 2: capture varargs now — task.spawn callback cannot access ... directly
	local args = { ... }

	-- step 3: queue fn in a new scheduler-managed coroutine
	--         fn does not run yet — task.spawn returns immediately, caller continues to step 4
	task.spawn(function()
		-- later step A: create a coroutine for fn so guard's coroutine.yield returns here
		local co = coroutine.create(fn)

		-- later step B: run fn — blocks inside this coroutine until guard fires or fn finishes
		--               if fn calls task.wait or other yielding APIs, the scheduler handles those transparently
		--               coroutine.resume only returns when guard fires or fn completes entirely
		local ok, value = coroutine.resume(co, table.unpack(args))

		-- later step C: fn crashed — pass the error to the caller's coroutine as a second value
		--               error() inside task.spawn dies silently and never reaches the caller,
		--               so we resume the caller with (nil, errorMessage) instead
		if not ok then
			task.spawn(callerCo, nil, value)
			return
		end

		-- later step D: fn completed normally or guard fired — resume caller with the return value
		--               both cases look identical: value is either fn's return or guard's returnValue
		task.spawn(callerCo, value)
	end)

	-- step 4: suspend the caller — yields control to the scheduler so step 3's fn can now run
	--         execution pauses here until task.spawn(callerCo, ...) is called in later step C or D
	--         coroutine.yield() returns whatever values were passed to task.spawn(callerCo, ...)
	local value, err = coroutine.yield()

	-- step 5: if a crash was passed from later step C, re-throw it on the caller's thread
	--         this ensures the error propagates to the nearest Catch boundary normally
	if err then
		error(err, 2)
	end

	return value :: any
end

-- Structured resource management

export type Scope = {
	add: (self: Scope, resource: any, cleanupFn: (resource: any) -> ()) -> (),
	addJanitorItem: (self: Scope, object: any, methodName: (string | boolean)?) -> (),
	addPromise: (self: Scope, promise: any) -> any,
}

type ScopeInternal = Scope & {
	_janitor: any,
}

local function newScope(): Scope
	local scope = setmetatable({
		_janitor = Janitor.new(),
	}, {
		__index = {
			--[=[
				Registers a resource with a cleanup function.
				The cleanup function is guaranteed to run when the scope exits,
				regardless of whether the operation succeeded, failed, or defected.
				@param resource any -- The resource to track
				@param cleanupFn function -- Called with the resource on scope exit
			]=]
			add = function(self: ScopeInternal, resource: any, cleanupFn: (resource: any) -> ())
				self._janitor:Add(function()
					cleanupFn(resource)
				end, true)
			end,

			--[=[
				Registers a Janitor-native item directly (Instance, RBXScriptConnection, etc.).
				Equivalent to calling `janitor:Add(object, methodName)` on the internal Janitor.
				@param object any -- Any Janitor-trackable object
				@param methodName string | boolean? -- Cleanup method name; defaults to Janitor's inference
			]=]
			addJanitorItem = function(self: ScopeInternal, object: any, methodName: (string | boolean)?)
				self._janitor:Add(object, methodName)
			end,

			--[=[
				Registers a Promise with the scope via Janitor:AddPromise.
				If the scope exits before the Promise resolves, the Promise is cancelled.
				Returns the same Promise so it can be used inline.
				@param promise Promise -- The Promise to track
				@return Promise -- The same Promise, now tracked by the scope
			]=]
			addPromise = function(self: ScopeInternal, promise: any): any
				return self._janitor:AddPromise(promise)
			end,
		},
	})
	return scope :: any
end

local function flushScope(scope: Scope)
	(scope :: ScopeInternal)._janitor:Cleanup()
end

--[=[
	Runs fn with a Scope, then flushes all registered cleanup functions on exit.
	Cleanup is guaranteed to run whether fn returns Ok, Err, or Defect.
	Use to manage multiple resources with different lifetimes inside one operation.

	```lua
	Result.scoped(function(scope)
	    local conn = scope:addJanitorItem(part.Touched:Connect(onTouch))
	    scope:add(openFile("data.txt"), function(file) file:Close() end)
	    return doWork()
	end)
	```
	@within Result
	@param fn function -- Receives a Scope; must return a Result
	@return Result -- The Result returned by fn, or a Defect if fn crashed
]=]
function Result.scoped(fn: (scope: Scope) -> Result<any>): Result<any>
	local scope = newScope()
	local ok, result = xpcall(fn, function(thrown)
		if type(thrown) == "table" and (thrown :: any)._isResult then
			return thrown
		end
		return Result.Defect(tostring(thrown), debug.traceback(nil, 2))
	end, scope)
	flushScope(scope)
	if not ok then
		return result :: any
	end
	if not Result.isResult(result) then
		return Result.Ok(result)
	end
	return result :: any
end

--[=[
	Acquires a resource, uses it, then releases it — guaranteed.
	Release runs whether use returned Ok, Err, or Defect.
	release receives the acquired value and must not throw.

	```lua
	Result.acquireRelease(
	    function() return openConnection() end,
	    function(conn) conn:Close() end,
	    function(conn) return conn:Query("SELECT 1") end
	)
	```
	@within Result
	@param acquire function -- () -> Result<T>; get the resource
	@param release function -- (T) -> (); always called, must not throw
	@param use function -- (T) -> Result<U>; use the resource
	@return Result -- Ok with use's value, or the first Err/Defect encountered
]=]
function Result.acquireRelease<T, U>(
	acquire: () -> Result<T>,
	release: (resource: T) -> (),
	use: (resource: T) -> Result<U>
): Result<U>
	local acquireResult = acquire()
	if not acquireResult.success then
		return acquireResult :: any
	end
	local resource = (acquireResult :: Ok<T>).value
	return Result.scoped(function(scope: Scope)
		scope:add(resource, release)
		return use(resource)
	end)
end

return table.freeze(Result)

