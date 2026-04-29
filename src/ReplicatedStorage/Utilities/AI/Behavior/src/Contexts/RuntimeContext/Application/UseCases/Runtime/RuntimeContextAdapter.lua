--!strict

--[=[
	@class RuntimeContextAdapter
	Normalizes runtime-context bags into executor service and delta-time inputs.
	@server
	@client
]=]

local Types = require(script.Parent.Parent.Parent.Parent.Parent.Parent.SharedDomain.Types)

local RuntimeContextAdapter = {}

--[=[
	Returns the executor service bag from a runtime context.
	@within RuntimeContextAdapter
	@param runtimeContext TActionRuntimeContext -- Runtime context bag or raw service bag
	@return any -- Executor services passed through to executor methods
]=]
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

--[=[
	Returns the delta time from a runtime context bag, accepting alternate field names.
	@within RuntimeContextAdapter
	@param runtimeContext TActionRuntimeContext -- Runtime context bag that may carry time fields
	@return number -- Delta time forwarded to executor ticks
]=]
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
