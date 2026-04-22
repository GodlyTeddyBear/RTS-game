--!strict

--[=[
	@class ExecutorRegistry
	Stores combat action executors and cancels them during teardown.
	@server
]=]
local ExecutorRegistry = {}
ExecutorRegistry.__index = ExecutorRegistry

--[=[
	@within ExecutorRegistry
	Creates a new executor registry with an empty action map.
	@return ExecutorRegistry -- Registry instance that stores action executors.
]=]
function ExecutorRegistry.new()
	local self = setmetatable({}, ExecutorRegistry)
	self._registry = {}
	return self
end

--[=[
	@within ExecutorRegistry
	Registers one executor for a specific combat action id.
	@param actionId string -- Non-empty action id used to look up the executor.
	@param executor any -- Executor object registered for the action.
]=]
function ExecutorRegistry:Register(actionId: string, executor: any)
	assert(type(actionId) == "string" and #actionId > 0, "ExecutorRegistry:Register requires non-empty actionId")
	self._registry[actionId] = executor
end

--[=[
	@within ExecutorRegistry
	Returns the executor registered for the requested action id.
	@param actionId string? -- Action id to look up.
	@return any? -- Registered executor or `nil` when the id is invalid or missing.
]=]
function ExecutorRegistry:Get(actionId: string?)
	if type(actionId) ~= "string" or #actionId == 0 then
		return nil
	end
	return self._registry[actionId]
end

--[=[
	@within ExecutorRegistry
	Cancels every registered executor for one entity during teardown.
	@param entity number -- Enemy entity id being torn down.
	@param services any -- Shared executor services used during cancellation.
]=]
function ExecutorRegistry:CancelAll(entity: number, services: any)
	for _, executor in pairs(self._registry) do
		pcall(function()
			executor:Cancel(entity, services)
		end)
	end
end

return ExecutorRegistry
