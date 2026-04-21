--!strict

--[=[
	@class BaseExecutor
	Defines the default executor lifecycle used by combat actions.
	@server
]=]
local BaseExecutor = {}
BaseExecutor.__index = BaseExecutor

-- Creates a new executor with the supplied action metadata.
function BaseExecutor.new(config: { ActionId: string, IsCommitted: boolean, Duration: number? })
	local self = setmetatable({}, BaseExecutor)
	self.Config = config
	return self
end

-- Starts an action and reports whether execution can continue.
function BaseExecutor:Start(_entity: number, _data: any?, _services: any): (boolean, string?)
	return true, nil
end

-- Advances an action by one tick and returns the current execution status.
function BaseExecutor:Tick(_entity: number, _dt: number, _services: any): string
	return "Running"
end

-- Cancels any in-flight state associated with the action.
function BaseExecutor:Cancel(_entity: number, _services: any)
end

-- Finalizes the action after a successful completion.
function BaseExecutor:Complete(_entity: number, _services: any)
end

return BaseExecutor
