--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Result = require(ReplicatedStorage.Utilities.Result)

--[=[
	@class WrapContext
	Wraps context client methods with structured error handling using Result types.
	@server
]=]

-- Wraps a function to catch errors and convert them to Result types for structured propagation.
-- The wrapper uses xpcall to intercept throws, converting unstructured errors into Defects
-- and allowing functions to return Result types which get unwrapped.
local function wrapFn(fn: any, label: string): any
	return function(self, ...)
		-- Execute the function and catch any throws via xpcall
		local ok, result = xpcall(fn, function(thrown)
			-- Check if the thrown value is already a Result (e.g., from Catch() in a method)
			if type(thrown) == "table" and (thrown :: any)._isResult then
				return thrown
			end
			-- Convert unstructured errors to Defect Results with full traceback
			return Result.Defect(tostring(thrown), debug.traceback(nil, 2))
		end, self, ...)

		-- Handle execution failure: an exception was thrown and not caught by the handler
		if not ok then
			-- Unstructured throw (no Catch ran) — log here since nothing else will
			warn(("[" .. label .. "]"), (result :: any).type, (result :: any).message)
			error(result, 0)
		end

		-- Process the return value: unwrap Results, pass through normal values
		if Result.isResult(result) then
			if not (result :: any).success then
				-- Already logged by the method's Catch handler
				error(result, 0)
			end
			return (result :: any).value
		end

		return result
	end
end

--[=[
	Wraps all client methods in a context with structured error handling.
	@within WrapContext
	@param context table -- The context object containing Client methods
	@param contextName string -- The context name for error logging
]=]
local function WrapContext(context: any, contextName: string)
	if context.Client then
		for name, fn in context.Client do
			if type(fn) == "function" then
				context.Client[name] = wrapFn(fn, contextName .. ".Client:" .. name)
			end
		end
	end
end

return WrapContext
