--!strict

local Core = require(script.Parent.Core)

local function zip(Result: any, resultA: Core.Result<any>, resultB: Core.Result<any>): Core.Result<any>
	if not resultA.success then
		return resultA
	end
	if not resultB.success then
		return resultB
	end
	return Result.Ok({ (resultA :: Core.Ok<any>).value, (resultB :: Core.Ok<any>).value })
end

local function zipWith(
	Result: any,
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

local function traverse(Result: any, items: { any }, fn: (any) -> Core.Result<any>): Core.Result<any>
	local results = table.create(#items)
	for i, item in items do
		results[i] = fn(item)
	end
	return Result.TryAll(table.unpack(results))
end

local function retry(Result: any, fn: () -> Core.Result<any>, options: { maxAttempts: number, delay: number? }): Core.Result<any>
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

return table.freeze({
	zip = zip,
	zipWith = zipWith,
	traverse = traverse,
	retry = retry,
})
