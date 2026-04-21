--!strict

--[=[
	@class ExecutorRegistry
	Stores combat action executors and cancels them during teardown.
	@server
]=]
local ExecutorRegistry = {}
ExecutorRegistry.__index = ExecutorRegistry

-- Creates a new executor registry with an empty action map.
function ExecutorRegistry.new()
	local self = setmetatable({}, ExecutorRegistry)
	self._registry = {}
	return self
end

-- Registers one executor for a specific combat action id.
function ExecutorRegistry:Register(actionId: string, executor: any)
	assert(type(actionId) == "string" and #actionId > 0, "ExecutorRegistry:Register requires non-empty actionId")
	self._registry[actionId] = executor
end

-- Returns the executor registered for the requested action id.
function ExecutorRegistry:Get(actionId: string?)
	if type(actionId) ~= "string" or #actionId == 0 then
		return nil
	end
	return self._registry[actionId]
end

-- Cancels every registered executor for one entity during teardown.
function ExecutorRegistry:CancelAll(entity: number, services: any)
	for _, executor in pairs(self._registry) do
		pcall(function()
			executor:Cancel(entity, services)
		end)
	end
end

return ExecutorRegistry
