--!strict

local Core = require(script.Parent.Core)
local function Try<T>(result: Core.Result<T>): T
	if not result.success then
		error(result)
	end
	return result.value
end

local function Ensure<T>(Result: any, condition: T, errType: string, message: string, data: { [string]: any }?): T
	if not condition then
		error(Result.Err(errType, message, data))
	end
	return condition
end

local function RequirePath(Result: any, root: any, ...: string): any
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

return table.freeze({
	Try = Try,
	Ensure = Ensure,
	RequirePath = RequirePath,
})
