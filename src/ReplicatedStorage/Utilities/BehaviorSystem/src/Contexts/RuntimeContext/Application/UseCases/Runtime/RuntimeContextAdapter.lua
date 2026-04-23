--!strict

local Types = require(script.Parent.Parent.Parent.Parent.Parent.Parent.SharedDomain.Types)

local RuntimeContextAdapter = {}

function RuntimeContextAdapter.GetExecutorServices(runtimeContext: Types.TActionRuntimeContext)
	if type(runtimeContext) ~= "table" then
		return runtimeContext
	end

	local services = runtimeContext.Services
	if services ~= nil then
		return services
	end

	return runtimeContext
end

function RuntimeContextAdapter.GetDeltaTime(runtimeContext: Types.TActionRuntimeContext): number
	if type(runtimeContext) ~= "table" then
		return 0
	end

	local deltaTime = runtimeContext.DeltaTime
	if type(deltaTime) == "number" then
		return deltaTime
	end

	local dt = runtimeContext.Dt
	if type(dt) == "number" then
		return dt
	end

	return 0
end

return table.freeze(RuntimeContextAdapter)
