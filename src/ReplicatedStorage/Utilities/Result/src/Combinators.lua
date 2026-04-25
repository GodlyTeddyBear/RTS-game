--!strict

local Combinators = {}

local Core = require(script.Parent.Core)

function Combinators.Apply(Result: any)
	--[=[
		Combines two successful Results into `Ok({ valueA, valueB })`.
		@within Result
	]=]
	function Result.zip(resultA: Core.Result<any>, resultB: Core.Result<any>): Core.Result<any>
		if not resultA.success then
			return resultA
		end
		if not resultB.success then
			return resultB
		end
		return Result.Ok({ (resultA :: Core.Ok<any>).value, (resultB :: Core.Ok<any>).value })
	end

	--[=[
		Combines two successful Results with a merge function.
		@within Result
	]=]
	function Result.zipWith(
		resultA: Core.Result<any>,
		resultB: Core.Result<any>,
		fn: (any, any) -> any
	): Core.Result<any>
		if not resultA.success then
			return resultA
		end
		if not resultB.success then
			return resultB
		end
		return Result.Ok(fn((resultA :: Core.Ok<any>).value, (resultB :: Core.Ok<any>).value))
	end

	--[=[
		Maps a Result-returning function over a list and accumulates failures.
		@within Result
	]=]
	function Result.traverse(items: { any }, fn: (any) -> Core.Result<any>): Core.Result<any>
		local results = table.create(#items)
		for i, item in items do
			results[i] = fn(item)
		end
		return Result.TryAll(table.unpack(results))
	end

	--[=[
		Retries a Result-returning function until success, defect, or max attempts.
		@within Result
	]=]
	function Result.retry(fn: () -> Core.Result<any>, options: { maxAttempts: number, delay: number? }): Core.Result<any>
		local lastResult: Core.Result<any> = Result.Err("RetryFailed", "No attempts made")
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
end

return Combinators
