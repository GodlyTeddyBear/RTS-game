--!strict

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

function IdleExecutor:OnTick(_entity: number, _dt: number, _services: any): string
	print("Idling")
	return self:Running()
end

return IdleExecutor
