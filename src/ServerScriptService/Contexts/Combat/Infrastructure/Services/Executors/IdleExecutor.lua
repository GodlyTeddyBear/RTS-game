--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BaseExecutor = require(ReplicatedStorage.Utilities.BaseExecutor)

--[=[
	@class IdleExecutor
	Keeps an entity in a running state without performing movement.
	@server
]=]
local IdleExecutor = {}
IdleExecutor.__index = IdleExecutor
setmetatable(IdleExecutor, { __index = BaseExecutor })

--[=[
	@within IdleExecutor
	Creates a new no-op executor for fallback behavior tree branches.
	@return IdleExecutor -- Idle executor instance.
]=]
function IdleExecutor.new()
	local self = BaseExecutor.new({
		ActionId = "Idle",
		IsCommitted = false,
	})
	return setmetatable(self, IdleExecutor)
end

--[=[
	@within IdleExecutor
	Returns running forever so the idle branch stays active.
	@param _entity number -- Enemy entity id being processed.
	@param _dt number -- Frame delta time for the current tick.
	@param _services any -- Shared executor services for the current tick.
	@return string -- Always returns `Running`.
]=]
function IdleExecutor:Tick(_entity: number, _dt: number, _services: any): string
	return "Running"
end

return IdleExecutor
