--!strict

--[=[
	@class Result
	Structured error handling with exception propagation.

	Use `Ok` and `Err` for expected flow, `Try` and `Ensure` inside `Catch`
	boundaries, and the chain methods to transform or recover without leaving
	the Result system.

	This public entry module preserves the legacy require path:
	`require(ReplicatedStorage.Utilities.Result)`.
]=]

local Result = require(script.src)

export type Ok<T> = Result.Ok<T>
export type Err = Result.Err
export type Result<T> = Result.Result<T>
export type ResultChain = Result.ResultChain
export type ResultTypeRegistry = Result.ResultTypeRegistry
export type ErrorLogger = Result.ErrorLogger
export type MilestoneLogger = Result.MilestoneLogger
export type Scope = Result.Scope

return Result
