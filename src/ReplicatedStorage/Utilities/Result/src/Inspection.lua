--!strict

local Core = require(script.Parent.Core)

local function sandbox(Result: any, result: Core.Result<any>): Core.Ok<Core.Result<any>>
	return Result.Ok(result)
end

local function unsandbox(sandboxed: Core.Ok<Core.Result<any>>): Core.Result<any>
	return sandboxed.value
end

return table.freeze({
	sandbox = sandbox,
	unsandbox = unsandbox,
})
