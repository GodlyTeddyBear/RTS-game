--!strict

--[=[
	@class BaseExecutor
	Defines the default executor lifecycle used by combat actions.
	@server
	@client
]=]
local BaseExecutor = {}
BaseExecutor.__index = BaseExecutor

--[=[
	@within BaseExecutor
	Creates a new executor with the supplied action metadata.
	@param config { ActionId: string, IsCommitted: boolean, Duration: number? } -- Executor metadata used by subclasses.
	@return BaseExecutor -- Base executor instance.
]=]
function BaseExecutor.new(config: { ActionId: string, IsCommitted: boolean, Duration: number? })
	local self = setmetatable({}, BaseExecutor)
	self.Config = config
	return self
end

--[=[
	@within BaseExecutor
	Starts an action and reports whether execution can continue.
	@param _entity number -- Enemy entity id being processed.
	@param _data any? -- Action payload supplied by the behavior tree.
	@param _services any -- Shared executor services for the current tick.
	@return boolean -- Whether the action can start.
	@return string? -- Optional failure reason when the action cannot start.
]=]
function BaseExecutor:Start(_entity: number, _data: any?, _services: any): (boolean, string?)
	return true, nil
end

--[=[
	@within BaseExecutor
	Advances an action by one tick and returns the current execution status.
	@param _entity number -- Enemy entity id being processed.
	@param _dt number -- Frame delta time for the current tick.
	@param _services any -- Shared executor services for the current tick.
	@return string -- Current action status.
]=]
function BaseExecutor:Tick(_entity: number, _dt: number, _services: any): string
	return "Running"
end

--[=[
	@within BaseExecutor
	Cancels any in-flight state associated with the action.
	@param _entity number -- Enemy entity id being processed.
	@param _services any -- Shared executor services for the current tick.
]=]
function BaseExecutor:Cancel(_entity: number, _services: any)
end

--[=[
	@within BaseExecutor
	Finalizes the action after a successful completion.
	@param _entity number -- Enemy entity id being processed.
	@param _services any -- Shared executor services for the current tick.
]=]
function BaseExecutor:Complete(_entity: number, _services: any)
end

return BaseExecutor
