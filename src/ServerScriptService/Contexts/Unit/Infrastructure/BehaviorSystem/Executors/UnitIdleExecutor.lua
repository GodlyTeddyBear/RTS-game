--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local BaseExecutor = require(ServerStorage.Utilities.ContextUtilities.BaseExecutor)

local UnitIdleExecutor = {}
UnitIdleExecutor.__index = UnitIdleExecutor
setmetatable(UnitIdleExecutor, BaseExecutor)

function UnitIdleExecutor.new()
	local self = BaseExecutor.new({
		ActionId = "Unit.Idle",
		IsCommitted = false,
	})
	return setmetatable(self, UnitIdleExecutor)
end

function UnitIdleExecutor:OnTick(_entity: number, _dt: number, _services: any): string
	return self:Running()
end

return UnitIdleExecutor
