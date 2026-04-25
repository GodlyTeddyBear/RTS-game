--!strict

local Inspection = {}

local Core = require(script.Parent.Core)

function Inspection.Apply(Result: any)
	--[=[
		Wraps a Result in `Ok` so it can be inspected as inert data.
		@within Result
	]=]
	function Result.sandbox(result: Core.Result<any>): Core.Ok<Core.Result<any>>
		return Result.Ok(result)
	end

	--[=[
		Unwraps a sandboxed Result back into the active error channel.
		@within Result
	]=]
	function Result.unsandbox(sandboxed: Core.Ok<Core.Result<any>>): Core.Result<any>
		return sandboxed.value
	end
end

return Inspection
