--!strict

local ControlFlow = {}

function ControlFlow.Apply(Result: any)
	--[=[
		Exits the current `gen` block early when the condition is falsy.
		@within Result
	]=]
	function Result.guard(condition: any, returnValue: any?)
		if not condition then
			coroutine.yield(returnValue)
		end
	end

	--[=[
		Runs a function in a coroutine so `guard` can return early.
		@within Result
	]=]
	function Result.gen<T>(fn: (...any) -> T, ...: any): T
		local callerCo = coroutine.running()
		local args = { ... }

		task.spawn(function()
			local co = coroutine.create(fn)
			local ok, value = coroutine.resume(co, table.unpack(args))

			if not ok then
				task.spawn(callerCo, nil, value)
				return
			end

			task.spawn(callerCo, value)
		end)

		local value, err = coroutine.yield()
		if err then
			error(err, 2)
		end

		return value :: any
	end
end

return ControlFlow
