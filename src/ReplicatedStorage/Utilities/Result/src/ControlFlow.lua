--!strict

local function guard(condition: any, returnValue: any?)
	if not condition then
		coroutine.yield(returnValue)
	end
end

local function gen<T>(fn: (...any) -> T, ...: any): T
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

return table.freeze({
	guard = guard,
	gen = gen,
})
