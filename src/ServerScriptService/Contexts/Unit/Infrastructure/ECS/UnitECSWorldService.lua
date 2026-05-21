--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local BaseECSWorldService = require(ServerStorage.Utilities.ECSUtilities.BaseECSWorldService)

local UnitECSWorldService = {}
UnitECSWorldService.__index = UnitECSWorldService
setmetatable(UnitECSWorldService, { __index = BaseECSWorldService })

function UnitECSWorldService.new()
	return setmetatable(BaseECSWorldService.new("Unit"), UnitECSWorldService)
end

return UnitECSWorldService
