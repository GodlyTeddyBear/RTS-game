--!strict

local Boundary = {}

local Core = require(script.Parent.Core)

function Boundary.Apply(Result: any, log: (level: string, label: string, err: any) -> ())
	--[=[
		Accumulates multiple Results into one success or a `MultipleErrors` failure.
		@within Result
	]=]
	function Result.TryAll(...: Core.Result<any>): Core.Result<{ any }>
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

	--[=[
		Converts a nil-able value into `Ok(value)` or `Err`.
		@within Result
	]=]
	function Result.fromNilable(value: any, errType: string, message: string, data: { [string]: any }?): Core.Result<any>
		if value == nil then
			return Result.Err(errType, message, data)
		end
		return Result.Ok(value)
	end

	--[=[
		Converts a `pcall`-style operation into a Result.
		@within Result
	]=]
	function Result.fromPcall(errType: string, fn: (...any) -> ...any, ...: any): Core.Result<any>
		local ok, result = pcall(fn, ...)
		if not ok then
			return Result.Err(errType, tostring(result))
		end
		return Result.Ok(result)
	end

	--[=[
		Runs the error boundary, logs failures, and always returns a Result.
		@within Result
	]=]
	function Result.Catch<T>(
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
end

return Boundary
