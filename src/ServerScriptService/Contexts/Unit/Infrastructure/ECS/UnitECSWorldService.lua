--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BaseECSWorldService = require(ReplicatedStorage.Utilities.BaseECSWorldService)

local UnitECSWorldService = {}
UnitECSWorldService.__index = UnitECSWorldService
setmetatable(UnitECSWorldService, { __index = BaseECSWorldService })

function UnitECSWorldService.new()
	return setmetatable(BaseECSWorldService.new("Unit"), UnitECSWorldService)
end

return UnitECSWorldService
