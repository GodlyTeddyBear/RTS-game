--!strict

local Core = require(script.Core)
local Logging = require(script.Logging)
local Throwable = require(script.Throwable)
local Boundary = require(script.Boundary)
local Inspection = require(script.Inspection)
local Combinators = require(script.Combinators)
local Async = require(script.Async)
local ControlFlow = require(script.ControlFlow)
local ScopeModule = require(script.Scope)

export type Ok<T> = Core.Ok<T>
export type Err = Core.Err
export type Result<T> = Core.Result<T>
export type ResultChain = Core.ResultChain
export type ResultTypeRegistry = Core.ResultTypeRegistry
export type ErrorLogger = Logging.ErrorLogger
export type MilestoneLogger = Logging.MilestoneLogger
export type Scope = ScopeModule.Scope

type TimeoutPromise = any

--[=[
	@class Result
	Structured error handling with exception propagation.
]=]

--[=[
	@prop Types ResultTypeRegistry
	@within Result
	Common built-in Result error type names.
]=]

--[=[
	@prop Ok function
	@within Result
	Wraps a success value into a Result.
]=]

--[=[
	@prop Err function
	@within Result
	Wraps an expected business failure into a Result.
]=]

--[=[
	@prop Defect function
	@within Result
	Wraps an unexpected runtime failure into a defect Result.
]=]

--[=[
	@prop isResult function
	@within Result
	Returns whether a value is a Result object.
]=]

--[=[
	@prop Try function
	@within Result
	Unwraps `Ok` or throws the failure for the nearest `Catch`.
]=]

--[=[
	@prop Ensure function
	@within Result
	Returns a truthy condition or throws a structured `Err`.
]=]

--[=[
	@prop RequirePath function
	@within Result
	Walks nested string keys or throws `MissingPath`.
]=]

--[=[
	@prop TryAll function
	@within Result
	Accumulates multiple Results into one success or a `MultipleErrors` failure.
]=]

--[=[
	@prop fromNilable function
	@within Result
	Converts a nil-able value into `Ok(value)` or `Err`.
]=]

--[=[
	@prop fromPcall function
	@within Result
	Converts a `pcall`-style operation into a Result.
]=]

--[=[
	@prop Catch function
	@within Result
	Runs the error boundary, logs failures, and always returns a Result.
]=]

--[=[
	@prop sandbox function
	@within Result
	Wraps a Result in `Ok` so it can be inspected as inert data.
]=]

--[=[
	@prop unsandbox function
	@within Result
	Unwraps a sandboxed Result back into the active error channel.
]=]

--[=[
	@prop zip function
	@within Result
	Combines two successful Results into `Ok({ valueA, valueB })`.
]=]

--[=[
	@prop zipWith function
	@within Result
	Combines two successful Results with a merge function.
]=]

--[=[
	@prop traverse function
	@within Result
	Maps a Result-returning function over a list and accumulates failures.
]=]

--[=[
	@prop retry function
	@within Result
	Retries a Result-returning function until success, defect, or max attempts.
]=]

--[=[
	@prop timeout function
	@within Result
	Runs a yielding function and resolves with a timeout `Err` if it takes too long.
]=]

--[=[
	@prop race function
	@within Result
	Runs yielding functions concurrently and resolves with the first Result.
]=]

--[=[
	@prop all function
	@within Result
	Runs yielding functions concurrently and resolves with all Results.
]=]

--[=[
	@prop guard function
	@within Result
	Exits the current `gen` block early when the condition is falsy.
]=]

--[=[
	@prop gen function
	@within Result
	Runs a function in a coroutine so `guard` can return early.
]=]

--[=[
	@prop scoped function
	@within Result
	Runs a function with a cleanup scope that always flushes on exit.
]=]

--[=[
	@prop acquireRelease function
	@within Result
	Acquires one resource, uses it, and guarantees release through a scope.
]=]

local Result = {}
local ResultMeta = Core.CreateMeta(Result)
Result.Types = Core.Types

--[=[
	Wraps a success value into a Result.
	@within Result
]=]
function Result.Ok<T>(value: T): Ok<T>
	return setmetatable({
		_isResult = true,
		success = true,
		value = value,
	}, ResultMeta) :: any
end

--[=[
	Wraps an expected business failure into a Result.
	@within Result
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
	Wraps an unexpected runtime crash into a defect Result.
	@within Result
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

--[=[
	Returns whether a value is a Result object.
	@within Result
]=]
function Result.isResult(value: any): boolean
	return type(value) == "table" and value._isResult == true
end

--[=[
	Registers the error log handler used by `Catch` and `MentionError`.
	@within Result
]=]
function Result.SetLogger(fn: ErrorLogger)
	Logging.SetLogger(fn)
end

--[=[
	Registers the success milestone log handler.
	@within Result
]=]
function Result.SetSuccessLogger(fn: MilestoneLogger)
	Logging.SetSuccessLogger(fn)
end

--[=[
	Registers the event milestone log handler.
	@within Result
]=]
function Result.SetEventLogger(fn: MilestoneLogger)
	Logging.SetEventLogger(fn)
end

--[=[
	Records a success milestone if a success logger is registered.
	@within Result
]=]
function Result.MentionSuccess(label: string, message: string, data: { [string]: any }?)
	Logging.MentionSuccess(label, message, data)
end

--[=[
	Records an event milestone if an event logger is registered.
	@within Result
]=]
function Result.MentionEvent(label: string, message: string, data: { [string]: any }?)
	Logging.MentionEvent(label, message, data)
end

--[=[
	Records an issue through the standard error logger without returning a Result.
	@within Result
]=]
function Result.MentionError(label: string, message: string, data: { [string]: any }?, errType: string?)
	Logging.MentionError(label, message, data, errType)
end

--[=[
	Unwraps `Ok` or throws the failure for the nearest `Catch`.
	@within Result
]=]
function Result.Try<T>(result: Result<T>): T
	return Throwable.Try(result)
end

--[=[
	Returns a truthy condition or throws a structured `Err`.
	@within Result
]=]
function Result.Ensure<T>(condition: T, errType: string, message: string, data: { [string]: any }?): T
	return Throwable.Ensure(Result, condition, errType, message, data)
end

--[=[
	Walks nested string keys or throws `MissingPath`.
	@within Result
]=]
function Result.RequirePath(root: any, ...: string): any
	return Throwable.RequirePath(Result, root, ...)
end

--[=[
	Accumulates multiple Results into one success or a `MultipleErrors` failure.
	@within Result
]=]
function Result.TryAll(...: Result<any>): Result<{ any }>
	return Boundary.TryAll(Result, ...)
end

--[=[
	Converts a nil-able value into `Ok(value)` or `Err`.
	@within Result
]=]
function Result.fromNilable(value: any, errType: string, message: string, data: { [string]: any }?): Result<any>
	return Boundary.fromNilable(Result, value, errType, message, data)
end

--[=[
	Converts a `pcall`-style operation into a Result.
	@within Result
]=]
function Result.fromPcall(errType: string, fn: (...any) -> ...any, ...: any): Result<any>
	return Boundary.fromPcall(Result, errType, fn, ...)
end

--[=[
	Runs the error boundary, logs failures, and always returns a Result.
	@within Result
]=]
function Result.Catch<T>(
	fn: (...any) -> Result<T> | any?,
	label: string,
	failureHandler: ((err: Err) -> ())?,
	...: any
): Result<T>
	return Boundary.Catch(Result, Logging.log, fn, label, failureHandler, ...)
end

--[=[
	Wraps a Result in `Ok` so it can be inspected as inert data.
	@within Result
]=]
function Result.sandbox(result: Result<any>): Ok<Result<any>>
	return Inspection.sandbox(Result, result)
end

--[=[
	Unwraps a sandboxed Result back into the active error channel.
	@within Result
]=]
function Result.unsandbox(sandboxed: Ok<Result<any>>): Result<any>
	return Inspection.unsandbox(sandboxed)
end

--[=[
	Combines two successful Results into `Ok({ valueA, valueB })`.
	@within Result
]=]
function Result.zip(resultA: Result<any>, resultB: Result<any>): Result<any>
	return Combinators.zip(Result, resultA, resultB)
end

--[=[
	Combines two successful Results with a merge function.
	@within Result
]=]
function Result.zipWith(resultA: Result<any>, resultB: Result<any>, fn: (any, any) -> any): Result<any>
	return Combinators.zipWith(Result, resultA, resultB, fn)
end

--[=[
	Maps a Result-returning function over a list and accumulates failures.
	@within Result
]=]
function Result.traverse(items: { any }, fn: (any) -> Result<any>): Result<any>
	return Combinators.traverse(Result, items, fn)
end

--[=[
	Retries a Result-returning function until success, defect, or max attempts.
	@within Result
]=]
function Result.retry(fn: () -> Result<any>, options: { maxAttempts: number, delay: number? }): Result<any>
	return Combinators.retry(Result, fn, options)
end

--[=[
	Runs a yielding function and resolves with a timeout `Err` if it takes too long.
	@within Result
]=]
function Result.timeout(fn: () -> Result<any>, seconds: number, errType: string?): TimeoutPromise
	return Async.timeout(Result, fn, seconds, errType)
end

--[=[
	Runs yielding functions concurrently and resolves with the first Result.
	@within Result
]=]
function Result.race(fns: { () -> Result<any> }): TimeoutPromise
	return Async.race(Result, fns)
end

--[=[
	Runs yielding functions concurrently and resolves with all Results.
	@within Result
]=]
function Result.all(fns: { () -> Result<any> }): TimeoutPromise
	return Async.all(Result, fns)
end

--[=[
	Exits the current `gen` block early when the condition is falsy.
	@within Result
]=]
function Result.guard(condition: any, returnValue: any?)
	ControlFlow.guard(condition, returnValue)
end

--[=[
	Runs a function in a coroutine so `guard` can return early.
	@within Result
]=]
function Result.gen<T>(fn: (...any) -> T, ...: any): T
	return ControlFlow.gen(fn, ...)
end

--[=[
	Runs a function with a cleanup scope that always flushes on exit.
	@within Result
]=]
function Result.scoped(fn: (scope: Scope) -> Result<any>): Result<any>
	return ScopeModule.scoped(Result, fn)
end

--[=[
	Acquires one resource, uses it, and guarantees release through a scope.
	@within Result
]=]
function Result.acquireRelease<T, U>(
	acquire: () -> Result<T>,
	release: (resource: T) -> (),
	use: (resource: T) -> Result<U>
): Result<U>
	return ScopeModule.acquireRelease(Result, acquire, release, use)
end

return table.freeze(Result)
