--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local BaseExecutor = require(ServerStorage.Utilities.ContextUtilities.BaseExecutor)

local SummonIdleExecutor = {}
SummonIdleExecutor.__index = SummonIdleExecutor
setmetatable(SummonIdleExecutor, BaseExecutor)

function SummonIdleExecutor.new()
	local self = BaseExecutor.new({
		ActionId = "Summon.Idle",
		IsCommitted = false,
	})
	return setmetatable(self, SummonIdleExecutor)
end

function SummonIdleExecutor:OnTick(_entity: number, _dt: number, _services: any): string
	return self:Running()
end

return SummonIdleExecutor
