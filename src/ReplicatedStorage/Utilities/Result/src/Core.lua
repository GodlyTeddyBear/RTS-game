--!strict

local Core = {}

--[=[
	@class Result
	Structured error handling with exception propagation.
]=]

--[=[
	@interface ResultChain
	@within Result
	.andThen function -- Transforms an `Ok` value into another `Result`.
	.orElse function -- Recovers from a business `Err`.
	.tapError function -- Observes failures without changing the `Result`.
	.mapError function -- Re-labels a business `Err`.
	.filter function -- Converts an `Ok` into an `Err` when rejected.
	.filterOrElse function -- Builds an `Err` from a rejected `Ok` value.
	.tap function -- Observes `Ok` values without changing the `Result`.
	.tapBoth function -- Observes either outcome without changing the `Result`.
	.map function -- Unwraps `Ok`, transforms it, and throws on failure.
	.unwrapOr function -- Returns the success value or a fallback.
]=]
export type ResultChain = {
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

export type ResultTypeRegistry = {
	RuntimeError: string,
	MultipleErrors: string,
	MissingPath: string,
}

function Core.Apply(Result: any)
	local ResultMeta = {}
	ResultMeta.__index = ResultMeta

	--[=[
		Applies `fn` to an `Ok` value and returns its Result.
		@within Result
	]=]
	function ResultMeta:andThen(fn: (any) -> any): any
		if not self.success then
			return self
		end
		return fn(self.value)
	end

	--[=[
		Recovers from a business `Err`; defects pass through unchanged.
		@within Result
	]=]
	function ResultMeta:orElse(fn: (Err) -> any): any
		if self.success or (self :: any).isDefect then
			return self
		end
		return fn(self :: any)
	end

	--[=[
		Runs a side effect for any failure and returns the original Result.
		@within Result
	]=]
	function ResultMeta:tapError(fn: (any) -> ()): any
		if not self.success then
			fn(self)
		end
		return self
	end

	--[=[
		Transforms a business `Err`; `Ok` and defects pass through unchanged.
		@within Result
	]=]
	function ResultMeta:mapError(fn: (Err) -> Err): any
		if not self.success and not (self :: any).isDefect then
			return fn(self :: any)
		end
		return self
	end

	--[=[
		Converts an `Ok` into an `Err` when the predicate fails.
		@within Result
	]=]
	function ResultMeta:filter(
		predicate: (any) -> boolean,
		errType: string,
		message: string,
		data: ({ [string]: any })?
	): any
		if self.success and not predicate(self.value) then
			return Result.Err(errType, message, data)
		end
		return self
	end

	--[=[
		Converts an `Ok` into an `Err` built from the rejected value.
		@within Result
	]=]
	function ResultMeta:filterOrElse(predicate: (any) -> boolean, fn: (any) -> Err): any
		if self.success and not predicate(self.value) then
			return fn(self.value)
		end
		return self
	end

	--[=[
		Runs a side effect for `Ok` and returns the original Result.
		@within Result
	]=]
	function ResultMeta:tap(fn: (any) -> ()): any
		if self.success then
			fn(self.value)
		end
		return self
	end

	--[=[
		Runs an outcome-specific side effect and returns the original Result.
		@within Result
	]=]
	function ResultMeta:tapBoth(onOk: (any) -> (), onErr: (any) -> ()): any
		if self.success then
			onOk(self.value)
		else
			onErr(self)
		end
		return self
	end

	--[=[
		Unwraps `Ok`, applies `fn`, and throws on failure.
		@within Result
	]=]
	function ResultMeta:map(fn: (any) -> any): any
		if not self.success then
			error(self)
		end
		return fn(self.value)
	end

	--[=[
		Returns the `Ok` value or a default on failure.
		@within Result
	]=]
	function ResultMeta:unwrapOr(default: any): any
		if self.success then
			return self.value
		end
		return default
	end

	Result.Types = table.freeze({
		RuntimeError = "RuntimeError",
		MultipleErrors = "MultipleErrors",
		MissingPath = "MissingPath",
	})

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
end

return Core
