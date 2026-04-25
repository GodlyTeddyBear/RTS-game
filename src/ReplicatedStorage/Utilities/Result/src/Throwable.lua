--!strict

local Throwable = {}

local Core = require(script.Parent.Core)

function Throwable.Apply(Result: any)
	--[=[
		Unwraps `Ok` or throws the failure for the nearest `Catch`.
		@within Result
	]=]
	function Result.Try<T>(result: Core.Result<T>): T
		if not result.success then
			error(result)
		end
		return result.value
	end

	--[=[
		Returns a truthy condition or throws a structured `Err`.
		@within Result
	]=]
	function Result.Ensure<T>(condition: T, errType: string, message: string, data: { [string]: any }?): T
		if not condition then
			error(Result.Err(errType, message, data))
		end
		return condition
	end

	--[=[
		Walks nested string keys or throws `MissingPath`.
		@within Result
	]=]
	function Result.RequirePath(root: any, ...: string): any
		local current = root
		for _, key in { ... } do
			if type(current) ~= "table" then
				error(Result.Err("MissingPath", "Expected table at '" .. key .. "', got " .. type(current)))
			end
			local next = current[key]
			if next == nil then
				error(Result.Err("MissingPath", "Path broke at '" .. key .. "'"))
			end
			current = next
		end
		return current
	end
end

return Throwable
