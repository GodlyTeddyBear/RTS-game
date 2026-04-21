--!strict

local BaseExecutor = require(script.Parent.Base.BaseExecutor)

--[=[
	@class IdleExecutor
	Keeps an entity in a running state without performing movement.
	@server
]=]
local IdleExecutor = {}
IdleExecutor.__index = IdleExecutor
setmetatable(IdleExecutor, { __index = BaseExecutor })

-- Creates a no-op executor for fallback behavior tree branches.
function IdleExecutor.new()
	local self = BaseExecutor.new({
		ActionId = "Idle",
		IsCommitted = false,
	})
	return setmetatable(self, IdleExecutor)
end

-- Returns running forever so the idle branch stays active.
function IdleExecutor:Tick(_entity: number, _dt: number, _services: any): string
	return "Running"
end

return IdleExecutor
