--!strict

--[=[
    @class IdleExecutor
    Keeps a unit in its idle behavior state when no higher-priority behavior is active.

    @server
]=]

local ServerStorage = game:GetService("ServerStorage")

local BaseExecutor = require(ServerStorage.Utilities.ContextUtilities.BaseExecutor)

local IdleExecutor = {}
IdleExecutor.__index = IdleExecutor
setmetatable(IdleExecutor, BaseExecutor)

function IdleExecutor.new()
	local self = BaseExecutor.new({
		ActionId = "Unit.Idle",
		IsCommitted = false,
	})
	return setmetatable(self, IdleExecutor)
end

-- Returns the running state so the behavior graph can remain in the idle branch indefinitely.
function IdleExecutor:OnTick(_entity: number, _dt: number, _services: any): string
	return self:Running()
end

return IdleExecutor
