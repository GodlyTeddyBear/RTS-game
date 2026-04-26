--!strict

local Core = require(script.Parent.Core)

local function TryAll(Result: any, ...: Core.Result<any>): Core.Result<{ any }>
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
		return Result.Err(
			Result.Types.MultipleErrors,
			"Multiple failures: " .. table.concat(messages, "; "),
			{ errors = leafErrors }
		)
	end
	return Result.Ok(values)
end

local function fromNilable(Result: any, value: any, errType: string, message: string, data: { [string]: any }?): Core.Result<any>
	if value == nil then
		return Result.Err(errType, message, data)
	end
	return Result.Ok(value)
end

local function fromPcall(Result: any, errType: string, fn: (...any) -> ...any, ...: any): Core.Result<any>
	local ok, result = pcall(fn, ...)
	if not ok then
		return Result.Err(errType, tostring(result))
	end
	return Result.Ok(result)
end

local function Catch<T>(
	Result: any,
	log: (level: string, label: string, err: any) -> (),
	fn: (...any) -> Core.Result<T> | any?,
	label: string,
	failureHandler: ((err: Core.Err) -> ())?,
	...: any
): Core.Result<T>
	local ok, result = xpcall(fn, function(thrown)
		if type(thrown) == "table" and (thrown :: any)._isResult then
			return thrown
		end
		return Result.Defect(tostring(thrown), debug.traceback(nil, 2))
	end, ...)

	local function handleFailure(err: any)
		local level = err.isDefect and "error" or "warn"
		log(level, label, err)
		if failureHandler then
			failureHandler(err)
		end
	end

	if not ok then
		handleFailure(result)
		return result :: any
	end

	if not Result.isResult(result) then
		return Result.Ok(result) :: any
	end

	if not (result :: any).success then
		handleFailure(result)
	end

	return result :: any
end

return table.freeze({
	TryAll = TryAll,
	fromNilable = fromNilable,
	fromPcall = fromPcall,
	Catch = Catch,
})
