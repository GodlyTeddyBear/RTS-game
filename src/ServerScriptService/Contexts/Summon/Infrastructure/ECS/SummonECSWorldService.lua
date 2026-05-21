--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local BaseECSWorldService = require(ServerStorage.Utilities.ECSUtilities.BaseECSWorldService)

local SummonECSWorldService = {}
SummonECSWorldService.__index = SummonECSWorldService
setmetatable(SummonECSWorldService, { __index = BaseECSWorldService })

function SummonECSWorldService.new()
	return setmetatable(BaseECSWorldService.new("Summon"), SummonECSWorldService)
end

return SummonECSWorldService
