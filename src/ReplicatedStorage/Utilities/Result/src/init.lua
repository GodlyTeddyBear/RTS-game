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

--[=[
	@interface ResultModule
	@within Result
	.Types ResultTypeRegistry -- Common built-in Result error type names.
	.Ok function -- Wraps a success value.
	.Err function -- Wraps an expected business failure.
	.Defect function -- Wraps an unexpected runtime failure.
	.isResult function -- Returns whether a value is a Result object.
	.Try function -- Unwraps `Ok` or throws the failure.
	.Ensure function -- Throws `Err` when the condition is falsy.
	.RequirePath function -- Walks nested string keys or throws `MissingPath`.
	.TryAll function -- Accumulates multiple Results into one.
	.fromNilable function -- Converts a nil-able value into a Result.
	.fromPcall function -- Converts a `pcall`-style operation into a Result.
	.Catch function -- Runs the error boundary and always returns a Result.
	.sandbox function -- Wraps a Result so it can be inspected as inert data.
	.unsandbox function -- Re-activates a sandboxed Result.
	.zip function -- Combines two successful Results.
	.zipWith function -- Combines two successful Results with a merge function.
	.traverse function -- Maps a Result-returning function over a list.
	.retry function -- Retries a Result-returning function.
	.timeout function -- Runs a yielding function with a timeout.
	.race function -- Resolves with the first Result to finish.
	.all function -- Resolves with all concurrent Results.
	.guard function -- Exits the current `gen` block early.
	.gen function -- Runs a function in a coroutine so `guard` can return early.
	.scoped function -- Runs work with guaranteed cleanup.
	.acquireRelease function -- Single-resource acquire/use/release helper.
]=]
export type ResultModule = {
	Types: ResultTypeRegistry,
	Ok: <T>(value: T) -> Ok<T>,
	Err: (errType: string, message: string, data: { [string]: any }?) -> Err,
	Defect: (message: string, traceback: string?) -> Err,
	isResult: (value: any) -> boolean,
	Try: <T>(result: Result<T>) -> T,
	Ensure: <T>(condition: T, errType: string, message: string, data: { [string]: any }?) -> T,
	RequirePath: (root: any, ...string) -> any,
	TryAll: (...Result<any>) -> Result<{ any }>,
	fromNilable: (value: any, errType: string, message: string, data: { [string]: any }?) -> Result<any>,
	fromPcall: (errType: string, fn: (...any) -> ...any, ...any) -> Result<any>,
	Catch: <T>(
		fn: (...any) -> Result<T> | any?,
		label: string,
		failureHandler: ((err: Err) -> ())?,
		...any
	) -> Result<T>,
	sandbox: (result: Result<any>) -> Ok<Result<any>>,
	unsandbox: (sandboxed: Ok<Result<any>>) -> Result<any>,
	zip: (resultA: Result<any>, resultB: Result<any>) -> Result<any>,
	zipWith: (resultA: Result<any>, resultB: Result<any>, fn: (any, any) -> any) -> Result<any>,
	traverse: (items: { any }, fn: (any) -> Result<any>) -> Result<any>,
	retry: (fn: () -> Result<any>, options: { maxAttempts: number, delay: number? }) -> Result<any>,
	timeout: (fn: () -> Result<any>, seconds: number, errType: string?) -> TimeoutPromise,
	race: (fns: { () -> Result<any> }) -> TimeoutPromise,
	all: (fns: { () -> Result<any> }) -> TimeoutPromise,
	guard: (condition: any, returnValue: any?) -> (),
	gen: <T>(fn: (...any) -> T, ...any) -> T,
	scoped: (fn: (scope: Scope) -> Result<any>) -> Result<any>,
	acquireRelease: <T, U>(
		acquire: () -> Result<T>,
		release: (resource: T) -> (),
		use: (resource: T) -> Result<U>
	) -> Result<U>,
}

local Result: ResultModule = {} ::ResultModule

Core.Apply(Result)
local log = Logging.Apply(Result)
Throwable.Apply(Result)
Boundary.Apply(Result, log)
Inspection.Apply(Result)
Combinators.Apply(Result)
Async.Apply(Result)
ControlFlow.Apply(Result)
ScopeModule.Apply(Result)

return table.freeze(Result)
